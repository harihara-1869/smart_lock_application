# Session Lifecycle & Management

This document details the lifecycle, orchestration, and state machine of NFC sessions in the Smart Lock application.

## 1. The Transport Layer
At the lowest level, all communication is abstracted through the `IsoDepTransport` interface. This allows the application to remain decoupled from the specific OS implementations (like Android's `nfc_manager`) and enables injecting a `FakeIsoDepTransport` for exhaustive unit testing.

- **`AndroidIsoDepTransport`**: Wraps `NfcManagerAndroid.enableReaderMode()`. It emits `TransportEvent.tagDiscovered` when a tag enters the RF field and `TransportEvent.tagLost` when it leaves or errors out.

## 2. SessionController
The `SessionController` is the beating heart of the application. It acts as the bridge between raw byte arrays and the cryptographic state machine. 

### State Machine (`TransportState`)
The session transitions strictly through these states:
1. **`idle`**: The initial state. No RF field is active.
2. **`activated`**: `startDiscovery()` was called, and an ISO-DEP tag has entered the field.
3. **`handshake`**: M1 has been sent. The M1/M2/M3 mutual authentication exchange is currently running.
4. **`secureSession`**: M3 was verified by the lock. The `SecureChannel` is initialized with symmetric keys (`K_p2e` / `K_e2p`).
5. **`released`**: The session has ended (either through success, error, or manual abortion) and the RF field has been killed.

### Normal Session Execution
1. A domain facade (like `LockConnection.unlock`) calls `startSession(lockId)`.
2. The phone resolves its long-term Identity (Ed25519 keypair) and the target lock's public key from secure storage.
3. The phone waits for a tag (with a 30-second timeout).
4. `_runHandshake()` executes the M1 -> M2 -> M3 sequence, actively verifying `Sig_L` at M2.
5. Once established, `sendSecureCommand(plaintext)` encrypts the payload via AES-256-GCM, wraps it in an APDU (INS `0x20`), and sends it. 
6. `abort()` is called to terminate the RF field.

## 3. Provisioning Sessions
Provisioning introduces a "chicken-and-egg" problem: the phone needs to securely talk to the lock, but doesn't know the lock's public key to verify the handshake (M2).

To solve this, `startProvisioningSession()` executes a **Dual-Deferred Handshake**:
- It runs the standard handshake but *skips* verifying the lock's signature (`Sig_L`) at M2, caching it in a `DeferredM2` object instead.
- It sends M3 and establishes a tentative secure session.
- The app sends `CMD_PROVISION` containing the 32-byte secret (from the QR code) and the phone's public key.
- The lock validates the secret. If valid, it returns its public key.
- The `ProvisionController` extracts this public key and *finally* verifies the cached `DeferredM2` signature.
- If it passes, the lock is saved to the `TrustedLocksStore`.

## 4. Hardware Interaction Lifecycles
Because NFC requires physical proximity, the RF field's lifecycle is critical to UX and battery life.
- The RF field is ONLY active between `startSession()` and `abort()`. 
- If a user triggers a session but walks away, a strict 30-second `TimeoutException` drops the RF field to prevent infinite polling.
- Manual cancellations immediately fire `stopDiscovery()` to kill Android's reader mode.
