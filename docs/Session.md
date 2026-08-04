# Session Lifecycle & Transport — Mobile Application Specification

This document specifies the lifecycle, orchestration, and state machine of NFC sessions in the Smart Lock mobile application, and the transport layer that carries the protocol. It is the Phone-side counterpart to the Firmware Engineering Specification Part IV (Transport) and Part I §8 (Session Lifecycle).

---

## 1. The Transport Layer

All communication is abstracted through the [`IsoDepTransport`](file:///workspaces/mobile_application/smartlock_application/lib/core/nfc_transport/iso_dep_transport.dart) interface. This keeps the application decoupled from OS-specific implementations and enables injecting a `FakeIsoDepTransport` for exhaustive unit testing.

### 1.1 Interface Contract

```dart
abstract class IsoDepTransport {
  Stream<TransportEvent> get events;
  Future<Result<void, TransportError>> startDiscovery();
  Future<void> stopDiscovery();
  Future<Result<Uint8List, TransportError>> transceive(Uint8List commandApdu);
  bool get isConnected;
  Future<void> disconnect();
}
```

**Usage lifecycle:**
1. `startDiscovery()` — begin polling for ISO-DEP tags (returns `TransportError.nfcUnavailable` if the hardware is off or missing).
2. Listen on `events` for `TagDiscovered`.
3. `transceive()` — exchange raw APDU bytes (precondition: `isConnected == true`).
4. On `TagLost` or when done, `stopDiscovery()` / `disconnect()`.

### 1.2 Transport Events

```dart
sealed class TransportEvent {
  TagDiscovered();  // an ISO-DEP tag entered the field and is ready for transceive
  TagLost();        // the connected tag was lost
}
```

### 1.3 Transport Errors

```dart
sealed class TransportError {
  notConnected();                 // no tag connected
  tagLost();                      // tag lost during a transceive
  timeout();                      // transceive timed out
  transceiveFailed(String msg);   // general failure with diagnostic
  nfcUnavailable();               // hardware off or missing
}
```

### 1.4 `AndroidIsoDepTransport`

Implemented in [`android_iso_dep_transport.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/nfc_transport/android_iso_dep_transport.dart), backed by `nfc_manager` v4.2.1.

- Uses `NfcManagerAndroid.enableReaderMode()` with flags `nfcA`, `nfcB`, `skipNdefCheck`, `noPlatformSounds` for tag discovery.
- On tag discovery, extracts `IsoDepAndroid` for raw transceive. **No `SELECT` (AID) step is performed** — M1 (INS `0x10`) is the first application-level APDU after ISO-DEP activation.
- Emits `TransportEvent.tagDiscovered` on entry and `TransportEvent.tagLost` when the tag leaves or a transceive throws.
- The underlying Android `IsoDep` handle is valid from `onTagDiscovered` until the tag is lost or `disableReaderMode()` is called — there is no explicit `connect()` / `close()` lifecycle.
- Transceive errors are heuristically classified: `TagLostException`/`Tag was lost` → `tagLost`; timeout → `timeout`; otherwise → `transceiveFailed`.

### 1.5 `FakeIsoDepTransport`

A scriptable test double in [`fake_iso_dep_transport.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/nfc_transport/fake_iso_dep_transport.dart):

- `simulateTagDiscovered()` / `simulateTagLost()` — drive connection events.
- `enqueueResponse(bytes)` / `enqueue(expectedCommand, responseBytes)` — enqueue scripted responses, optionally validating the incoming command.
- `enqueueCallback(callback)` — build the response dynamically from the incoming command (used to produce a valid M2 from a random M1).
- `enqueueError(transportError)` — enqueue a transport error.
- `allConsumed` / `remainingCount` — verify all enqueued entries were consumed.

---

## 2. `SessionController`

The [`SessionController`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/session_controller.dart) is the bridge between raw byte arrays and the cryptographic state machine. It owns the `TransportState` state machine, the `SecureChannel` created after M3, and the `HandshakeContext` created at M1.

### 2.1 Construction

```dart
SessionController({
  required IsoDepTransport transport,
  required LockKeyResolver resolveLockKey,       // String lockId -> Uint8List? pubkey
  required PhoneIdentityResolver resolvePhoneIdentity, // () -> (seed, publicKey)
})
```

- `LockKeyResolver` — resolves a lock ID to the lock's Ed25519 public key (32 bytes), or `null` if unknown. Satisfied by `TrustedLocksStore.getLockPublicKey`.
- `PhoneIdentityResolver` — returns the phone's long-term Ed25519 identity. Satisfied by `IdentityKeystore.getOrCreateIdentity`.

### 2.2 State Machine (`TransportState`)

```
IDLE → ACTIVATED → HANDSHAKE → SECURE_SESSION → RELEASED
```

Any state can transition to `RELEASED` on error or abort.

| State | Meaning |
|---|---|
| `idle` | Initial state. No RF field active. |
| `activated` | `startDiscovery()` called; an ISO-DEP tag has entered the field. |
| `handshake` | M1 sent; the M1/M2/M3 mutual-authentication exchange is running. |
| `secureSession` | M3 verified by the lock; `SecureChannel` initialized with `K_p2e` / `K_e2p`. |
| `released` | Session ended (success, error, or manual abort); RF field killed. |

### 2.3 Normal Session Execution (`startSession(lockId)`)

1. Guard: rejected with `invalidState` if a session is already active.
2. Resolve the lock's Ed25519 public key via `_resolveLockKey`. `null` → `untrustedLock`.
3. Resolve the phone's long-term identity via `_resolvePhoneIdentity`.
4. `_runHandshake(lockPublicKey: <resolved>, phoneIdentity: ...)`:
   - `startDiscovery()`, then `_waitForTag()` (30-second timeout → `timeout`).
   - Set `activated`.
   - `Handshake.buildM1()` → send M1 (INS `0x10`).
   - Parse the M2 R-APDU. **Immediate verification:** `Handshake.parseAndVerifyM2` verifies `Sig_L` against the lock's public key. Failure → `authenticationFailed`, session released, RF killed.
   - Set `handshake`.
   - `Handshake.buildM3()` → send M3 (INS `0x11`). Non-OK status → `_mapM3Status` (SW `69 82` → `handshakeRejected`). The M3 ack must carry **zero** data bytes, else → `unexpected`.
   - Construct `SecureChannel(kP2E, kE2P)`; set `secureSession`.
5. The caller (a facade) sends commands via `sendSecureCommand`, then calls `abort()`.

### 2.4 Provisioning Session (`startProvisioningSession()`)

Provisioning introduces a chicken-and-egg problem: the phone must talk securely to the lock but does not yet know the lock's public key to verify M2.

**Design Decision: The Deferred Handshake.** Verification is never *skipped* — it is *deferred*. The phone:
1. Runs the standard handshake but caches `Sig_L` and the transcript in a `DeferredM2` via `Handshake.cacheM2ForProvisioning` (available through `SessionController.deferredM2`).
2. Sends M3 and establishes a tentative secure session.
3. Sends `CMD_PROVISION` containing the 32-byte QR secret and the phone's public key.
4. The lock validates the secret and returns its own public key.
5. `ProvisionController` extracts that key and *finally* verifies the cached `DeferredM2` signature with `Handshake.verifyDeferredM2`.
6. Only if the signature passes is the lock saved to `TrustedLocksStore`.

```dart
if (lockPublicKey != null) {
  // Normal session: verify Sig_L now.
  final m2Result = await Handshake.parseAndVerifyM2(
    m2Data: m1Rapdu.data, ctx: ctx, lockPublicKey: lockPublicKey,
  );
} else {
  // Provisioning: cache without verifying (deferred).
  final m2Result = await Handshake.cacheM2ForProvisioning(
    m2Data: m1Rapdu.data, ctx: ctx,
  );
}
```

### 2.5 Secure Command (`sendSecureCommand(plaintext)`)

1. Guard: state must be `secureSession`, else → `invalidState`.
2. `SecureChannel.encrypt(plaintext)` (rejects > 199 bytes with `payloadTooLarge`).
3. Send as INS `0x20` C-APDU.
4. Parse the R-APDU. Non-OK status → `_mapSecurePayloadStatus` (SW `69 82` → `decryptionFailed`; session released).
5. **Empty R-APDU data** is returned as empty plaintext; the facade treats it as an application error. (Firmware-side: an empty successful ack is sent when the application task times out on the command handoff.)
6. `SecureChannel.decrypt(responseData)`; a GCM tag mismatch → `decryptionFailed`, session released.

### 2.6 Abort (`abort()`)

1. If the state is `activated`, `handshake`, or `secureSession`, sends `CMD_SESSION_ABORT` (INS `0x30`) best-effort — a transport error here is ignored since we are tearing down regardless.
2. `_release()` → state `released`, `SecureChannel` and `DeferredM2` cleared.
3. `stopDiscovery()` kills Android reader mode.

### 2.7 State Cleanup (`_release`)

`_release()` transitions to `released` and nulls `_secureChannel` and `_deferredM2`. It is invoked on every error path so no session state leaks between attempts.

---

## 3. Identity & Trusted Locks Storage

### 3.1 `IdentityKeystore`

Implemented in [`identity_keystore.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/identity_keystore.dart), backed by `FlutterSecureStorage`.

- Manages the phone's long-term Ed25519 keypair: a 32-byte seed (secret) and a 32-byte public key.
- Keys: `identity_ed25519_seed`, `identity_ed25519_pubkey` (hex-encoded).
- `getOrCreateIdentity()` — generates and persists on first call; reads from storage thereafter.
- `hasIdentity()`, `deleteIdentity()` — existence check and factory reset.

### 3.2 `TrustedLocksStore`

Implemented in [`trusted_locks_store.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/trusted_locks_store.dart), backed by `FlutterSecureStorage`.

- Stores a JSON map of `lockId → lock Ed25519 public key (hex)` under key `trusted_locks_json`.
- `getLockPublicKey(lockId)` — `null` if the lock is not trusted.
- `storeTrustedKey(lockId, lockPublicKey)` — written after successful provisioning.
- `removeTrustedKey(lockId)`, `listTrustedLocks()`.

---

## 4. Hardware Interaction Lifecycles

Because NFC requires physical proximity, the RF field lifecycle is critical to UX and battery life.

- The RF field is **only** active between `startDiscovery()` and `abort()` / `stopDiscovery()`.
- **Design Decision: Timeout Enforcement.** If a user triggers a session but walks away, a strict 30-second timeout (`_waitForTag` → `TimeoutException` → `NfcSessionError.timeout`) drops the RF field to prevent infinite polling.
- Manual cancellation (the UI "Cancel" buttons) immediately fires `abort()` → `stopDiscovery()` to kill Android reader mode.
- On every failure path, `_release()` clears crypto state so an aborted session can never contaminate the next one (mirroring the firmware's secure-erase requirement).

---

## 5. Timing, Liveness, and Session Guardrails

| Guardrail | Value | Enforced By |
|---|---|---|
| Tag-wait timeout | 30 s | `SessionController._waitForTag` |
| Secure plaintext ceiling | 199 bytes | `SecureChannel.encrypt` / `ProtocolConstants.maxSecurePlaintext` |
| M3 ack data | exactly 0 bytes | `SessionController._runHandshake` |
| Command response GCM | tag must verify | `SecureChannel.decrypt` |
| Session state transitions | strictly ordered | `TransportState` + guards in `startSession` / `sendSecureCommand` |

The firmware independently enforces its own handshake timeout (`T_HS`, recommended 2 s), frame-integrity checks, and secure-erase routine; the phone must tolerate a lock that tears the session down abruptly, which surfaces as `tagLost` or `unexpectedStatus`.
