# Master Reference: Connecting the Layers

This document serves as the top-level architectural blueprint, explaining how the hardware, OS, protocols, state management, and UI knit together to create the Smart Lock experience.

## The Architecture Stack
1. **User Interface (UI)**: Flutter widgets in `features/ui/screens/`. Handles human interaction and renders state.
2. **State Management (Riverpod)**: Maps domain controllers and data streams to the UI.
3. **Facades (Domain Logic)**: `LockConnection` and `ProvisionController`. Abstract away cryptographic complexity, exposing simple asynchronous functions like `.unlock(lockId)`.
4. **Session Controller**: The state machine. Manages the lifecycle of a physical NFC connection from discovery to handshake to secure channel.
5. **Cryptography Engine**: Pure math (X25519, Ed25519, AES-GCM) applied to byte arrays via `handshake.dart` and `secure_channel.dart`.
6. **Transport Layer**: `AndroidIsoDepTransport`. Directly commands the Android OS NFC daemon to generate RF fields and exchange raw APDUs.
7. **Physical World**: The actual Smart Lock hardware (ESP32 + PN532).

---

## Trace: The Provisioning Journey (Phase 13)
*Goal: Associate a brand new lock with the user's phone.*

1. **Physical Intent**: User opens the box, presses a button on the lock to wake it up (Step 1).
2. **Data Acquisition**: User scans the QR code in the app (Step 2). The `mobile_scanner` extracts a 64-character hex string. `QrProvisionParser` converts this into a 32-byte `provisionSecret`.
3. **Session Initiation**: The UI (Step 3) calls `ProvisionController.provisionLock()`.
4. **RF Activation**: The `SessionController` calls `startDiscovery()`. The phone emits an RF field. The user taps the phone to the lock. The OS fires `onTagDiscovered`.
5. **The Handshake (M1-M3)**: 
   - M1 and M2 are exchanged. 
   - **Crucial Deviation**: Because the phone doesn't know the lock yet, it *skips* verifying the lock's signature in M2 (`DeferredM2`).
   - M3 establishes a tentative `SecureChannel`.
6. **Authorization**: The phone encrypts `CMD_PROVISION`, packing the 32-byte secret and the phone's public key, and sends it.
7. **Lock Validation**: The physical lock checks if the secret matches its internal hardware secret. It succeeds, registers the phone's public key, and replies with its own public key.
8. **Final Verification**: The `ProvisionController` receives the lock's public key, reaches back to the `DeferredM2` object, and verifies the lock's signature. 
9. **Persistence & UI**: The signature passes. The lock's public key is saved to `TrustedLocksStore`. `trustedLocksNotifierProvider` refreshes, and the UI immediately shows the new lock.

---

## Trace: The Unlock Journey (Phase 14)
*Goal: Authenticated unlocking of a known door.*

1. **Intent**: The user selects their front door in the UI and taps "Tap to Unlock" in the `ActuateLockScreen`.
2. **Facade Call**: The UI triggers `lockConnection.unlock(lockId)`.
3. **Lookup**: `SessionController` fetches the phone's identity and looks up the lock's public key from `TrustedLocksStore`.
4. **RF Activation**: `startDiscovery()` powers up the RF field. The user taps the lock.
5. **Strict Handshake**: 
   - M1 is sent. M2 arrives.
   - The phone strictly verifies the lock's M2 signature *immediately* (unlike provisioning). 
   - If a malicious lock tries to spoof M2, the cryptographic verification fails, `abort()` is called, and the session drops instantly.
   - M3 is sent. The `SecureChannel` is established.
6. **Command Execution**: `LockConnection` encrypts `CMD_UNLOCK (0x02)` via AES-GCM and transmits it.
7. **Actuation**: The physical lock decrypts the command, verifies the GCM tag, and drives its physical motor to retract the deadbolt. It encrypts an `AppStatus.ok` response.
8. **Resolution**: The phone decrypts the `OK` response. The `finally` block calls `abort()`, killing the RF field. The UI state switches to `_success = true`, rendering a green pulsing "Unlocked!" animation.

*End of Document*
