# Master Reference: Connecting the Layers — Mobile Application Specification

This document is the top-level architectural blueprint for the Smart Lock mobile application. It explains how the UI, state management, domain facades, session controller, cryptography engine, and transport layer knit together, and how the whole stack maps to the peer firmware. Companion documents:

- [`Protocol.md`](file:///workspaces/mobile_application/smartlock_application/docs/Protocol.md) — the SLOCK-HS-v1 wire protocol (framing, handshake, crypto, commands).
- [`Session.md`](file:///workspaces/mobile_application/smartlock_application/docs/Session.md) — session lifecycle, transport, and state machine.
- [`State_Management.md`](file:///workspaces/mobile_application/smartlock_application/docs/State_Management.md) — Riverpod dependency injection and reactive state.
- [`UI_Design.md`](file:///workspaces/mobile_application/smartlock_application/docs/UI_Design.md) — design system and screen architecture.

The peer firmware contract is the Firmware Engineering Specification (`Smart_Lock.pdf`); this document set is the Phone-side engineering specification and shares its wire contract (handshake messages and command set).

---

## 1. The Architecture Stack

```
┌─────────────────────────────────────────────────────────────┐
│ UI  — Flutter widgets (lib/features/ui/screens/)            │
│       Human interaction & state rendering                   │
├─────────────────────────────────────────────────────────────┤
│ State — Riverpod (lib/core/providers/nfc_providers.dart)    │
│       Dependency injection & reactive state                 │
├─────────────────────────────────────────────────────────────┤
│ Facades — LockConnection, ProvisionController               │
│       Typed, high-level domain operations                   │
├─────────────────────────────────────────────────────────────┤
│ Session — SessionController, Handshake, SecureChannel       │
│       State machine + crypto (X25519/Ed25519/HKDF/AES-GCM)  │
├─────────────────────────────────────────────────────────────┤
│ Transport — IsoDepTransport / AndroidIsoDepTransport        │
│       Raw APDU exchange over ISO/IEC 14443-4 (ISO-DEP)      │
└─────────────────────────────────────────────────────────────┘
```

1. **User Interface (UI)**: Flutter widgets in [`lib/features/ui/screens/`](file:///workspaces/mobile_application/smartlock_application/lib/features/ui/screens/). Handles human interaction and renders state.
2. **State Management (Riverpod)**: Maps domain controllers and data streams to the UI. Registered in [`lib/core/providers/nfc_providers.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/providers/nfc_providers.dart).
3. **Facades (Domain Logic)**: [`LockConnection`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/facade/lock_connection.dart) and [`ProvisionController`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/provisioning/provision_controller.dart).
4. **Session Controller**: [`SessionController`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/session_controller.dart). The state machine managing the lifecycle of a physical NFC connection from discovery to handshake to secure channel.
5. **Cryptography Engine**: Pure math (X25519, Ed25519, AES-GCM) applied to byte arrays via [`Handshake`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/handshake.dart) and [`SecureChannel`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/secure_channel.dart).
6. **Transport Layer**: [`AndroidIsoDepTransport`](file:///workspaces/mobile_application/smartlock_application/lib/core/nfc_transport/android_iso_dep_transport.dart). Directly commands the Android OS NFC daemon to generate RF fields and exchange raw APDUs.

### Design Decision: Why Facades?

The underlying `SessionController` speaks in APDUs, nonces, and raw byte arrays. By wrapping it in facades, the UI layer only ever sees high-level, business-logic asynchronous functions like `.unlock(lockId)`. This strict separation of concerns makes testing the business logic trivial without spinning up the UI.

---

## 2. The Provisioning Journey

*Goal: Associate a brand new lock with the user's phone — a lock whose public key the phone does not yet know.*

1. **Physical Intent**: The user presses a button on the lock to wake it and arm its provisioning window (`Step1PressButtonScreen`).
2. **Data Acquisition**: The user scans the QR code in [`step_2_scan_qr.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/ui/screens/step_2_scan_qr.dart). The `mobile_scanner` extracts a 64-character hex string. [`QrProvisionParser`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/provisioning/qr_provision_parser.dart) converts this into a 32-byte `provisionSecret`.
   - **Design Decision:** The QR code contains *only* the secret, not the lock's public key. This keeps the QR code small and simple to parse, relying on the secure NFC channel to exchange actual identities.
3. **Session Initiation**: The UI ([`step_3_nfc_sync.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/ui/screens/step_3_nfc_sync.dart)) calls `ProvisionController.provisionLock()`.
4. **RF Activation**: The `SessionController` calls `startDiscovery()`. The phone emits an RF field. The user taps the phone to the lock. The OS fires `onTagDiscovered`.
5. **The Handshake (M1–M3)**:
   - M1 and M2 are exchanged.
   - **Crucial Deviation (Design Decision):** Because the phone doesn't know the lock yet, it *defers* verifying the lock's signature in M2 (`DeferredM2`). Verification is deferred, not skipped — the cached signature is checked moments later against the lock public key returned by `CMD_PROVISION`. If verification were enforced here, provisioning would be impossible.
   - M3 establishes a tentative `SecureChannel`.
6. **Authorization**: The phone encrypts `CMD_PROVISION`, packing the 32-byte secret and the phone's public key, and sends it.
7. **Lock Validation**: The physical lock checks if the secret matches its internal hardware secret. It succeeds, registers the phone's public key, and replies with its own public key.
8. **Final Verification**: The `ProvisionController` receives the lock's public key, reaches back to the `DeferredM2` object, and verifies the lock's signature.
9. **Persistence & UI**: The signature passes. The lock's public key is saved to [`TrustedLocksStore`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/trusted_locks_store.dart). `trustedLocksNotifierProvider` refreshes, and the UI immediately shows the new lock.

---

## 3. The Unlock Journey

*Goal: Authenticated unlocking of a known door.*

1. **Intent**: The user selects their front door in the UI and taps "Tap to Unlock" in [`actuate_lock_screen.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/ui/screens/actuate_lock_screen.dart).
2. **Facade Call**: The UI triggers `lockConnection.unlock(lockId)`.
3. **Lookup**: `SessionController` fetches the phone's identity and looks up the lock's public key from `TrustedLocksStore`.
4. **RF Activation**: `startDiscovery()` powers up the RF field. The user taps the lock.
5. **Strict Handshake**:
   - M1 is sent. M2 arrives.
   - **Design Decision: Immediate Verification:** The phone strictly verifies the lock's M2 signature *immediately* (unlike provisioning). If a malicious lock tries to spoof M2, the cryptographic verification fails, `abort()` is called, and the session drops instantly, preventing any payload leakage.
   - M3 is sent. The `SecureChannel` is established.
6. **Command Execution**: `LockConnection` encrypts `CMD_UNLOCK (0x02)` via AES-GCM and transmits it as an `INS 0x20` secure payload.
7. **Actuation**: The physical lock decrypts the command, verifies the GCM tag, and begins driving its physical motor to retract the deadbolt. It encrypts an `AppStatus.ok` response.
8. **Resolution**: The phone decrypts the `OK` response. The `finally` block calls `abort()`, killing the RF field. The UI state switches to `_success = true`, rendering a green "Unlocked!" state.

---

## 4. How the Layers Map to the Firmware

The firmware (ESP32) is the *target* of the SLOCK-HS-v1 protocol; the phone is the *initiator*. The mapping:

| Mobile Layer | Firmware Counterpart (Smart_Lock.pdf) |
|---|---|
| `AndroidIsoDepTransport` | Part V — Hardware/Link Layer (PN532) + Part IV Transport |
| `SessionController` / `Handshake` | Part I — Session Module (handshake, peer resolution) |
| `SecureChannel` / `CryptoPrimitives` | Part I §6–7 — Key derivation, secure messaging |
| `AppCommands` / `AppStatus` | Part II §4–5 — Application Module command set & status bytes |
| `LockConnection` / `ProvisionController` | Part II — Application Module (dispatch, authorization, provisioning) |

Wire contracts shared verbatim between the two documents:

- APDU framing: `CLA 0x80`, INS `0x10/0x11/0x20/0x30`, P1/P2 `0x00` (Short APDU, no `Le`).
- Handshake messages: M1 64 B, M2 128 B, M3 64 B; transcript `"SLOCK-HS-v1" ‖ 0x01 ‖ pk_eph_P ‖ pk_eph_L ‖ c_P ‖ c_L`.
- Key derivation: HKDF-SHA256, salt `c_P ‖ c_L`, info `"phone->esp"` / `"esp->phone"`.
- AES-256-GCM payload: `nonce(12) ‖ ciphertext ‖ tag(16)`, plaintext ceiling 199 bytes (firmware OI-1 flagged).
- Command set: `CMD_PROVISION 0x01`, `CMD_UNLOCK 0x02`, `CMD_LOCK 0x03`, `CMD_GET_STATUS 0x04`, `CMD_REVOKE_KEY 0x05`.
- Status bytes: `0x00` OK, `0x01` INVALID SECRET, `0x02` UNKNOWN CMD, `0x03` ACTUATOR FAULT.

---

## 5. Security Properties

| Property | Mechanism |
|---|---|
| Mutual device authentication | Ed25519 signatures over the full handshake transcript |
| Confidentiality | AES-256-GCM with directional keys |
| Integrity | AES-GCM authentication tag (16 B per message) |
| Key agreement | Ephemeral X25519, fresh per session |
| Key derivation | HKDF-SHA256, challenges bound into salt |
| Replay protection (handshake) | Fresh challenges in the signed transcript |
| Forward secrecy | Fresh X25519 keypair per session, destroyed at termination |
| Reflection resistance | Distinct directional keys `K_p2e` / `K_e2p` |

*End of Document*
