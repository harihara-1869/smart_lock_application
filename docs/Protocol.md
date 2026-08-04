# NFC Security Protocol (SLOCK-HS-v1)

The SLOCK-HS-v1 protocol is a bespoke, zero-trust, mutual-authentication and end-to-end encrypted protocol running directly over ISO 7816-4 short APDUs. It is primarily implemented in [`lib/features/session/handshake.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/handshake.dart) and [`lib/features/session/secure_channel.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/secure_channel.dart).

## 1. APDU Framing
Communication utilizes Command APDUs (C-APDU) and Response APDUs (R-APDU) with a proprietary Class byte `CLA = 0x80`.

- **C-APDU**: `[CLA 0x80] [INS] [P1 0x00] [P2 0x00] [Lc] [Data] [Le 0x00]`
- **R-APDU**: `[Data] [SW1] [SW2]`

### Key Instruction (INS) Codes
- `0x10`: `CMD_HANDSHAKE_INIT` (M1)
- `0x11`: `CMD_HANDSHAKE_FINISH` (M3)
- `0x20`: `CMD_SECURE_PAYLOAD` (Encrypted application commands)
- `0x30`: `CMD_SESSION_ABORT` (Best-effort teardown)

**Design Decision: The 0x20 Secure Envelope:** 
Why funnel all lock commands through a single `0x20` INS instead of assigning each command its own INS byte (e.g. `INS=0x02` for Unlock)? This ensures the Transport Layer state machine is totally blind to application business logic. The Transport layer simply enforces that `0x20` is only allowed *after* a secure session is established.

## 2. 3-Message Mutual Authentication (The Handshake)
Implemented in [`Handshake.initiate()`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/handshake.dart#L12). The handshake ensures both the Phone (P) and Lock (L) prove their identities before establishing symmetric session keys.

1. **M1 (Phone -> Lock)**:
   - Phone generates an ephemeral X25519 keypair (`sk_eph_P`, `pk_eph_P`).
   - Phone generates a 32-byte random challenge (`c_P`).
   - Payload: `pk_eph_P || c_P` (64 bytes).

2. **M2 (Lock -> Phone)**:
   - Lock generates ephemeral X25519 keypair (`pk_eph_L`) and challenge (`c_L`).
   - Lock signs the transcript (`T1`) using its long-term Ed25519 private key to produce `Sig_L`.
   - Payload: `pk_eph_L || c_L || Sig_L` (128 bytes).

3. **M3 (Phone -> Lock)**:
   - Phone verifies `Sig_L`. 
   - Phone computes the Shared Secret via X25519(`sk_eph_P`, `pk_eph_L`).
   - Phone derives Session Keys via HKDF-SHA256.
   - Phone signs transcript (`T2`) using its long-term Ed25519 private key to produce `Sig_P`.
   - Payload: `Sig_P` (64 bytes).
   - Lock replies with `0x90 0x00` if `Sig_P` is valid.

### The Transcript
To prevent replay and downgrade attacks, signatures are generated over a domain-separated transcript:
`"SLOCK-HS-v1" || 0x01 || pk_eph_P || pk_eph_L || c_P || c_L`

## 3. Session Keys & Encryption
Implemented in [`SecureChannel`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/secure_channel.dart). Once M3 is acknowledged, all further communication uses `CMD_SECURE_PAYLOAD`.

- **Key Derivation (HKDF-SHA256)**:
  - Salt: `c_P || c_L`
  - IKM: X25519 Shared Secret
  - `K_p2e` (Phone to ESP): `HKDF-Expand("phone->esp")`
  - `K_e2p` (ESP to Phone): `HKDF-Expand("esp->phone")`

**Design Decision: Directional Keys:** 
Why derive two separate keys (`K_p2e` and `K_e2p`) instead of one master symmetric key? It prevents reflection attacks. If an attacker records an encrypted message from the phone and replays it back to the phone, the phone will attempt to decrypt it using `K_e2p` (which expects lock-originated messages), causing AES-GCM tag verification to immediately fail.

- **AES-256-GCM Framing**:
  - The plaintext payload is encrypted using the directional key.
  - A 12-byte CSPRNG Nonce is generated per message.
  - The resulting ciphertext and 16-byte GCM authentication tag are packed:
    `Payload = [Nonce (12)] || [Ciphertext] || [Tag (16)]`

  *Implementation from `SecureChannel.encrypt()`:*
  ```dart
  Future<Result<Uint8List, NfcSessionError>> encrypt(
    Uint8List plaintext,
  ) async {
    if (plaintext.length > ProtocolConstants.maxSecurePlaintext) {
      return Result.err(
        NfcSessionError.payloadTooLarge(
          plaintext.length,
          ProtocolConstants.maxSecurePlaintext,
        ),
      );
    }

    final encrypted = await CryptoPrimitives.aesGcmEncrypt(
      key: _kP2E,
      plaintext: plaintext,
    );
    return Result.ok(encrypted);
  }
  ```

## 4. Application Commands (Plaintext inside GCM)
Once the secure channel is open, the phone sends 1-byte Application Commands inside the encrypted plaintext, defined in [`AppCommands`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/commands/app_commands.dart):
- `0x01`: `CMD_PROVISION` (Followed by 32B QR Secret + 32B Phone PubKey)
- `0x02`: `CMD_UNLOCK`
- `0x03`: `CMD_LOCK`
- `0x04`: `CMD_GET_STATUS`
- `0x05`: `CMD_REVOKE_KEY` (Followed by 32B Target Pubkey)

The lock replies with an encrypted payload where the first byte is an `AppStatus` (e.g., `0x00` = OK, `0x02` = Unauthorized), which is parsed by `LockConnection._mapAppStatus()` into Dart exceptions.
