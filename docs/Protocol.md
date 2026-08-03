# NFC Security Protocol (SLOCK-HS-v1)

The SLOCK-HS-v1 protocol is a bespoke, zero-trust, mutual-authentication and end-to-end encrypted protocol running directly over ISO 7816-4 short APDUs.

## 1. APDU Framing
Communication utilizes Command APDUs (C-APDU) and Response APDUs (R-APDU) with a proprietary Class byte `CLA = 0x80`.

- **C-APDU**: `[CLA 0x80] [INS] [P1 0x00] [P2 0x00] [Lc] [Data] [Le 0x00]`
- **R-APDU**: `[Data] [SW1] [SW2]`

### Key Instruction (INS) Codes
- `0x10`: `CMD_HANDSHAKE_INIT` (M1)
- `0x11`: `CMD_HANDSHAKE_FINISH` (M3)
- `0x20`: `CMD_SECURE_PAYLOAD` (Encrypted application commands)
- `0x30`: `CMD_SESSION_ABORT` (Best-effort teardown)

## 2. 3-Message Mutual Authentication (The Handshake)
The handshake ensures both the Phone (P) and Lock (L) prove their identities before establishing symmetric session keys.

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
Once M3 is acknowledged, all further communication uses `CMD_SECURE_PAYLOAD`.

- **Key Derivation (HKDF-SHA256)**:
  - Salt: `c_P || c_L`
  - IKM: X25519 Shared Secret
  - `K_p2e` (Phone to ESP): `HKDF-Expand("phone->esp")`
  - `K_e2p` (ESP to Phone): `HKDF-Expand("esp->phone")`

- **AES-256-GCM Framing**:
  - The plaintext payload is encrypted using the directional key.
  - A 12-byte CSPRNG Nonce is generated per message.
  - The resulting ciphertext and 16-byte GCM authentication tag are packed:
    `Payload = [Nonce (12)] || [Ciphertext] || [Tag (16)]`

## 4. Application Commands (Plaintext inside GCM)
Once the secure channel is open, the phone sends 1-byte Application Commands inside the encrypted plaintext:
- `0x01`: `CMD_PROVISION` (Followed by 32B QR Secret + 32B Phone PubKey)
- `0x02`: `CMD_UNLOCK`
- `0x03`: `CMD_LOCK`
- `0x04`: `CMD_GET_STATUS`
- `0x05`: `CMD_REVOKE_KEY` (Followed by 32B Target Pubkey)

The lock replies with an encrypted payload where the first byte is an `AppStatus` (e.g., `0x00` = OK, `0x02` = Unauthorized).
