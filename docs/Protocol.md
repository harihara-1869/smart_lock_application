# NFC Security Protocol (SLOCK-HS-v1) — Mobile Application Specification

The SLOCK-HS-v1 protocol is a bespoke, zero-trust, mutual-authentication and end-to-end encrypted protocol running directly over ISO/IEC 7816-4 short APDUs over an ISO/IEC 14443-4 (ISO-DEP) contactless link. This document specifies the Phone-side (Flutter) implementation of the protocol and is normative for the mobile application. It is the counterpart to the Firmware Engineering Specification, Part I (Session Module) and Part IV (Transport), and shares the same wire contract with them.

The protocol is implemented in:
- [`lib/features/nfc/`](file:///workspaces/mobile_application/smartlock_application/lib/features/nfc/) — APDU framing, protocol constants, status words, transport state.
- [`lib/features/session/handshake.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/handshake.dart) — M1/M2/M3 message construction, parsing, and verification.
- [`lib/features/session/secure_channel.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/secure_channel.dart) — AES-256-GCM authenticated encryption.
- [`lib/features/session/crypto/crypto_primitives.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/crypto/crypto_primitives.dart) — pure cryptographic primitives.
- [`lib/features/session/commands/app_commands.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/commands/app_commands.dart) — application-layer opcodes and status bytes.

---

## 1. Protocol Constants

All wire-level constants are centrally defined in [`ProtocolConstants`](file:///workspaces/mobile_application/smartlock_application/lib/features/nfc/protocol_constants.dart).

| Constant | Value | Purpose |
|---|---|---|
| `cla` | `0x80` | Proprietary class byte |
| `p1` / `p2` | `0x00` | Reserved; convention only, not validated by the transport |
| `insHandshakeInit` | `0x10` | M1: handshake init |
| `insHandshakeFinish` | `0x11` | M3: handshake finish |
| `insSecurePayload` | `0x20` | Encrypted application payload |
| `insSessionAbort` | `0x30` | Best-effort session teardown |
| `versionByte` | `0x01` | Handshake transcript version |
| `maxCommandData` | `255` | Short-APDU C-APDU data limit |
| `maxResponseData` | `256` | Short-APDU R-APDU data limit |
| `transportMaxLc` | `227` | Enforced ceiling for the complete encrypted package |
| `gcmNonceLength` | `12` | AES-GCM nonce length |
| `gcmTagLength` | `16` | AES-GCM authentication tag length |
| `maxSecurePlaintext` | `199` | `transportMaxLc − 28` (see §5.3) |
| `x25519KeyLength` | `32` | X25519 key size |
| `ed25519PubKeyLength` | `32` | Ed25519 public key size |
| `ed25519SigLength` | `64` | Ed25519 signature size |
| `challengeLength` | `32` | Handshake challenge size |
| `m1Length` | `64` | M1 payload size |
| `m2Length` | `128` | M2 payload size |
| `m3Length` | `64` | M3 payload size |
| `transcriptPrefix` | `"SLOCK-HS-v1"` | Transcript domain separator |
| `hkdfInfoPhoneToEsp` | `"phone->esp"` | HKDF-Expand info for K_p2e |
| `hkdfInfoEspToPhone` | `"esp->phone"` | HKDF-Expand info for K_e2p |
| `derivedKeyLength` | `32` | Derived key length for AES-256 |

---

## 2. APDU Framing

Communication uses Command APDUs (C-APDU) and Response APDUs (R-APDU) under ISO/IEC 7816-4 Short APDU (Case 1 / Case 3) conventions.

### 2.1 Command APDU (C-APDU): Phone → Lock

| Field | Size | Value |
|---|---|---|
| `CLA` | 1 byte | `0x80` (proprietary class) |
| `INS` | 1 byte | `0x10` / `0x11` / `0x20` / `0x30` |
| `P1` | 1 byte | `0x00` |
| `P2` | 1 byte | `0x00` |
| `Lc` | 0–1 byte | Length of data payload (omitted when empty) |
| `Data` | `Lc` bytes | Handshake parameters or AES-GCM secure payload |

**Case-1 APDU** (no data, e.g. `CMD_SESSION_ABORT`): `[CLA INS P1 P2]` — 4 bytes, `Lc` omitted.

**Case-3 APDU** (with data): `[CLA INS P1 P2 Lc Data]` — 5 + `Lc` bytes.

**No trailing `Le` byte is used.** The serialization is implemented in [`Capdu.toBytes()`](file:///workspaces/mobile_application/smartlock_application/lib/features/nfc/apdu.dart), which throws `ArgumentError` if `data.length > 255`.

### 2.2 Response APDU (R-APDU): Lock → Phone

| Field | Size | Value |
|---|---|---|
| `Data` | 0–256 bytes | Handshake response or encrypted application response |
| `SW1` | 1 byte | `0x90` = normal processing; see §3 |
| `SW2` | 1 byte | Status sub-code |

Parsed by [`Rapdu.fromBytes()`](file:///workspaces/mobile_application/smartlock_application/lib/features/nfc/apdu.dart): the last two bytes are always `SW1 SW2`; everything before them is response data.

### 2.3 Instruction Set (INS)

| Instruction | INS | Carries | Valid State |
|---|---|---|---|
| `CMD_HANDSHAKE_INIT` | `0x10` | M1, 64 bytes | `activated` |
| `CMD_HANDSHAKE_FINISH` | `0x11` | M3, 64 bytes | `handshake` |
| `CMD_SECURE_PAYLOAD` | `0x20` | AES-256-GCM encrypted application command | `secureSession` |
| `CMD_SESSION_ABORT` | `0x30` | none | any active state |

**Design Decision: The single `0x20` secure envelope.**
All application commands are funnelled through a single `INS = 0x20` instead of assigning each command its own INS byte (e.g. `INS = 0x02` for Unlock). This keeps the transport-layer state machine completely blind to application business logic — it only enforces that `0x20` is allowed *after* a secure session is established. The application opcode lives inside the decrypted plaintext (a distinct namespace; see §6).

### 2.4 Status Words (SW1/SW2)

Defined in [`StatusWord`](file:///workspaces/mobile_application/smartlock_application/lib/features/nfc/status_word.dart) and shared with the firmware transport dictionary:

| SW1 | SW2 | Mnemonic | Meaning |
|---|---|---|---|
| `0x90` | `0x00` | `ok` | Success |
| `0x69` | `0x82` | `authFailed` | Signature or AEAD tag verification failed |
| `0x69` | `0x85` | `wrongState` | INS not valid in the current transport state |
| `0x6A` | `0x80` | `invalidData` | Lc mismatch or payload too large |
| `0x6A` | `0x81` | `notSupported` | Unknown INS, or CLA ≠ `0x80` |

`StatusWord.fromBytes(sw1, sw2)` returns `unknown` for any unrecognized combination.

---

## 3. The 3-Message Mutual Authentication Handshake

The handshake ensures both the Phone (P) and Lock (L) prove their identities before establishing symmetric session keys. It is implemented in [`Handshake`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/handshake.dart).

### 3.1 Message Flow

```
Phone                                        Lock (ESP32)
  │  M1: pk_eph_P ‖ c_P (64 B, INS 0x10)       │
  ├───────────────────────────────────────────►│
  │                                            │  generate (sk_eph_L, pk_eph_L), c_L
  │                                            │  Sig_L = sign(T, sk_L)
  │  M2: pk_eph_L ‖ c_L ‖ Sig_L (128 B)        │
  │◄───────────────────────────────────────────┤
  │  verify Sig_L against PK_L                 │
  │  compute X25519(sk_eph_P, pk_eph_L)        │
  │  derive K_p2e, K_e2p via HKDF-SHA256       │
  │  Sig_P = sign(T, sk_P)                     │
  │  M3: Sig_P (64 B, INS 0x11)                │
  ├───────────────────────────────────────────►│
  │                                            │  resolve peer identity, verify Sig_P
  │  SW 90 00 (empty data) ◄───────────────────┤
  │                                            │  derive K_p2e, K_e2p
```

### 3.2 Message Definitions

| Msg | Sender | Contents |
|---|---|---|
| M1 | Phone | `pk_eph_P` (X25519, 32 B) ‖ `c_P` (32 B). Carries no identity hint. |
| M2 | Lock | `pk_eph_L` (32 B) ‖ `c_L` (32 B) ‖ `Sig_L` (Ed25519, 64 B) |
| M3 | Phone | `Sig_P` (Ed25519, 64 B) |

### 3.3 The Transcript

To prevent replay, splicing, and downgrade attacks, every signature is generated over a domain-separated transcript:

```
T = "SLOCK-HS-v1" ‖ 0x01 ‖ pk_eph_P ‖ pk_eph_L ‖ c_P ‖ c_L   (140 bytes)
```

Built by [`CryptoPrimitives.buildTranscript()`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/crypto/crypto_primitives.dart). Both platforms compute the identical transcript, so no signature is valid outside the session it was created for.

### 3.4 Verification Rules (Phone side)

1. Upon receiving M2, the Phone **MUST** verify `Sig_L` against the lock's long-term Ed25519 public key (resolved from `TrustedLocksStore`) before proceeding to M3. On failure it **MUST** abort without deriving any session key material.
2. The Phone **MUST** reject a handshake if `pk_eph_P` or `pk_eph_L` is the all-zero point or otherwise fails X25519 validity checks.
3. `c_P` **MUST** be generated with a CSPRNG and **MUST NOT** be reused across sessions.
4. The M3 acknowledgement **MUST** be `SW 90 00` with **zero** data bytes. Any data in the M3 ack is a protocol violation.

### 3.5 The `Handshake` API

| Function | Role |
|---|---|
| `Handshake.buildM1()` | Generates the ephemeral X25519 keypair, the challenge `c_P`, and returns the 64-byte M1 payload plus a `HandshakeContext` to thread through the exchange. |
| `Handshake.parseAndVerifyM2({m2Data, ctx, lockPublicKey})` | Parses M2, verifies `Sig_L` against `lockPublicKey`, computes the shared secret. Returns `M2Result`. |
| `Handshake.cacheM2ForProvisioning({m2Data, ctx})` | Parses M2 **without** verifying `Sig_L`, caching it in a `DeferredM2` for later verification. Used during provisioning. |
| `Handshake.buildM3({transcript, phoneSeed, phonePublicKey, sharedSecret, challengeP, challengeL})` | Produces the 64-byte M3 payload (`Sig_P`) and derives both directional session keys. |
| `Handshake.verifyDeferredM2({cached, lockPublicKey})` | Verifies a cached, unverified `Sig_L` against a lock public key received in the `CMD_PROVISION` response. |

`HandshakeContext`, `M2Result`, and `DeferredM2` are pure data holders owned by the `SessionController` across the M1→M2→M3 exchange.

---

## 4. Cryptographic Primitives

All primitives are pure, static, and side-effect-free, implemented in [`CryptoPrimitives`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/crypto/crypto_primitives.dart) over the `cryptography` Dart package.

| Primitive | Use | Notes |
|---|---|---|
| Ed25519 (RFC 8032) | Long-term identity signatures over the handshake transcript | 32-byte seed + 32-byte public key |
| X25519 (RFC 7748) | Ephemeral key agreement | All-zero output must be rejected |
| HKDF-SHA256 (RFC 5869) | Session-key derivation | Extract+Expand; challenges bound into the salt |
| AES-256-GCM | Authenticated encryption of application payloads | 12-byte nonce, 16-byte tag, empty AAD |
| CSPRNG | Nonces, ephemeral keys, challenges | `Random.secure()` |

No custom cryptographic primitives are implemented.

---

## 5. Session Keys & Secure Communication

Once M3 is acknowledged, all further communication uses `INS = 0x20` (`CMD_SECURE_PAYLOAD`). Implemented in [`SecureChannel`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/secure_channel.dart).

### 5.1 Key Derivation (HKDF-SHA256)

```
PRK   = HKDF-Extract(salt = c_P ‖ c_L, ikm = X25519 Shared Secret)
K_p2e = HKDF-Expand(PRK, info = "phone->esp", L = 32)
K_e2p = HKDF-Expand(PRK, info = "esp->phone", L = 32)
```

`CryptoPrimitives.deriveSessionKeys()` computes both keys in one call.

**Design Decision: Directional keys.**
Two separate keys (`K_p2e`, `K_e2p`) are derived instead of a single master key to prevent reflection attacks. If an attacker records an encrypted phone message and replays it back to the phone, the phone attempts to decrypt it with `K_e2p` (the lock-originated key), causing AES-GCM tag verification to immediately fail.

### 5.2 AES-256-GCM Message Format

Each encrypted message is packed as:

```
Payload = [Nonce (12)] ‖ [Ciphertext] ‖ [Tag (16)]
```

- Nonce: 12 bytes, CSPRNG-generated, unique per message per key.
- Ciphertext: AES-256-GCM output for the application-layer plaintext.
- Tag: 16-byte GCM authentication tag.
- AAD: empty (confirmed across both documents).

`SecureChannel.encrypt()` produces this wire format with `K_p2e`; `SecureChannel.decrypt()` parses it with `K_e2p` and maps a `SecretBoxAuthenticationError` to `NfcSessionError.decryptionFailed`.

### 5.3 Plaintext Capacity

`ProtocolConstants.maxSecurePlaintext = 199` bytes, computed as `transportMaxLc (227) − gcmNonceLength (12) − gcmTagLength (16)`. This matches the as-built firmware enforcement (the firmware rejects a `CMD_SECURE_PAYLOAD` C-APDU with `Lc > 227` via `SW 6A 80`). The originally-intended 227-byte figure is a known, flagged discrepancy (firmware OI-1); this implementation adopts the conservative, arithmetically-consistent 199 bytes. Exceeding the limit returns `NfcSessionError.payloadTooLarge`.

### 5.4 Replay Protection

Each session derives a fresh key and is short-lived and single-purpose. Sequence-number-based replay protection within a session is therefore optional at the protocol level; whether a given plaintext command is safe to replay is an application-layer policy decision. The handshake itself is replay-protected by fresh challenges in the signed transcript.

---

## 6. Application Commands (Plaintext inside GCM)

Once the secure channel is open, the phone sends a 1-byte opcode (plus arguments) inside the encrypted plaintext. Defined in [`AppCommands`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/commands/app_commands.dart).

### 6.1 Command Table

| Command | Opcode | Request Plaintext | Success Response |
|---|---|---|---|
| `CMD_PROVISION` | `0x01` | `[0x01] ‖ Secret (32 B) ‖ Phone_Ed25519_PK (32 B)` — 65 bytes | `[0x00] ‖ Lock_Ed25519_PK (32 B)` — 33 bytes |
| `CMD_UNLOCK` | `0x02` | `[0x02]` — 1 byte | `[0x00]` |
| `CMD_LOCK` | `0x03` | `[0x03]` — 1 byte | `[0x00]` |
| `CMD_GET_STATUS` | `0x04` | `[0x04]` — 1 byte | `[0x00] ‖ Battery_Pct (1 B) ‖ Lock_State (1 B) ‖ Last_Err (1 B)` |
| `CMD_REVOKE_KEY` | `0x05` | `[0x05] ‖ Target_Phone_PK (32 B)` — 33 bytes | `[0x00]` |

The opcode is a distinct namespace from the transport INS byte: the opcode lives inside the decrypted plaintext and is never visible on the wire.

### 6.2 Application Status Bytes

Per the Firmware Engineering Specification Part II §5.3 (normative):

| Value | Meaning |
|---|---|
| `0x00` | `APP_STATUS_OK` — command executed successfully |
| `0x01` | `APP_STATUS_INVALID_SECRET` — CMD_PROVISION only; the supplied secret did not match |
| `0x02` | `APP_STATUS_UNKNOWN_CMD` — opcode not present in the command table |
| `0x03` | `APP_STATUS_ACTUATOR_FAULT` — the actuator reported an unresolved/unknown state |

There is no `0x04` application status. The old "unauthorized / invalid command" statuses are not part of the protocol.

### 6.3 Lock State Bytes

Defined in [`LockState`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/commands/lock_status.dart):

| Value | Meaning |
|---|---|
| `0x00` | Locked (bolt confirmed by limit switch) |
| `0x01` | Unlocked |
| `0x02` | Unknown (intermediate or unresolved position) |

`LockState.fromByte()` maps `0x00` → `locked`, `0x01` → `unlocked`, and anything else → `unknown`.

---

## 7. Error Model

All expected failure modes are modeled as sealed [`NfcSessionError`](file:///workspaces/mobile_application/smartlock_application/lib/features/nfc/nfc_errors.dart) values returned as `Result.err` at layer boundaries. Real exceptions are reserved for programmer errors only.

| Error | Trigger |
|---|---|
| `tagLost` | Tag lost during NFC communication |
| `timeout` | NFC transceive timed out, or the 30-second tag-wait elapsed |
| `unexpectedStatus(sw1, sw2)` | Lock returned an unrecognized status word |
| `authenticationFailed` | Lock's M2 signature verification failed |
| `handshakeRejected` | Lock rejected M3 (`SW 69 82`) — hard handshake failure, not retryable |
| `decryptionFailed` | AES-GCM tag mismatch on a response — session is dead, do not retry with the same keys |
| `invalidState(current, operation)` | Invalid transport state for the requested operation |
| `untrustedLock` | Lock's public key is not in the trusted store |
| `nfcUnavailable` | NFC hardware not available or disabled |
| `payloadTooLarge(size, maxSize)` | Plaintext exceeds the 199-byte limit |
| `unexpected(message)` | Unexpected error with diagnostic message |

### 7.1 Status-Word → Error Mapping (context-dependent)

`SessionController` maps status words to errors differently depending on the protocol phase:

- **M1/M2 handshake** (`_mapHandshakeStatus`): `69 82` → `authenticationFailed`; `69 85` → `invalidState`; `6A 80` / `6A 81` → `unexpected`; otherwise → `unexpectedStatus`.
- **M3** (`_mapM3Status`): `69 82` → `handshakeRejected`; other non-OK statuses as above.
- **Secure payload** (`_mapSecurePayloadStatus`): `69 82` → `decryptionFailed` (an AES-GCM failure — the session is dead).

### 7.2 Transport Error → NfcSessionError Mapping

`_mapTransportError` translates `TransportError` values: `tagLost` → `tagLost`, `timeout` → `timeout`, `notConnected` → `invalidState`, `nfcUnavailable` → `nfcUnavailable`, `transceiveFailed` → `unexpected`.
