# State Management Architecture

The application relies exclusively on **Riverpod** for robust, compile-safe dependency injection and reactive state management. 

**Design Decision: Why Riverpod?**
Passing domain controllers (`LockConnection`, `SessionController`) heavily through the widget tree using `InheritedWidget` or `Provider` leads to boilerplate and brittle tests. Riverpod allows providers to be declared globally and resolves dependencies outside of the Flutter widget tree. This means we can instantiate and test `LockConnection` cleanly in pure Dart tests.

## 1. Provider Scope
The entire application is wrapped in a `ProviderScope` at the root in [`lib/main.dart`](file:///workspaces/mobile_application/smartlock_application/lib/main.dart). This ensures a unified container for all singletons and state notifiers.

## 2. Dependency Injection Registry (`nfc_providers.dart`)
Instead of passing controllers down the widget tree, we maintain a central registry of providers in [`lib/core/providers/nfc_providers.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/providers/nfc_providers.dart). This ensures that all components operate on the exact same hardware bindings and cryptographic keystores.

*Example Implementation:*
```dart
final sessionControllerProvider = Provider<SessionController>((ref) {
  final transport = ref.watch(isoDepTransportProvider);
  final identityKeystore = ref.watch(identityKeystoreProvider);
  final trustedLocksStore = ref.watch(trustedLocksStoreProvider);

  return SessionController(
    transport: transport,
    resolveLockKey: trustedLocksStore.getLockPublicKey,
    resolvePhoneIdentity: identityKeystore.getOrCreateIdentity,
  );
});
```

### Core Singletons
- **`loggerProvider`**: Global logging instance.
- **`secureStorageProvider`**: Binds to `FlutterSecureStorage` for hardware-backed keystore persistence.
- **`isoDepTransportProvider`**: Binds to `AndroidIsoDepTransport`.
- **`identityKeystoreProvider`**: Manages the phone's long-term Ed25519 identity.

### Domain Controllers
- **`sessionControllerProvider`**: Orchestrates the low-level handshake and APDU flow.
- **`lockConnectionProvider`**: Exposes high-level commands (`unlock`, `lock`, `revoke`) to the UI.
- **`provisionControllerProvider`**: Specifically orchestrates the dual-deferred provisioning flow.

## 3. Reactive State (The `TrustedLocksStore`)
Data that the UI needs to react to (like the list of trusted locks) is managed via `StateNotifierProvider`.

- **`TrustedLocksStore`**: Defined in [`lib/features/session/trusted_locks_store.dart`](file:///workspaces/mobile_application/smartlock_application/lib/features/session/trusted_locks_store.dart). This class directly interacts with `FlutterSecureStorage` to read/write trusted lock public keys.
- **`trustedLocksNotifierProvider`**: A `StateNotifier<AsyncValue<Map<String, Uint8List>>>`. 
  - On app launch, it asynchronously loads all saved keys and emits an `AsyncData` map.
  - The `MyKeysScreen` utilizes `ref.watch(trustedLocksNotifierProvider)` to instantly build the UI list.
  - When the `ProvisionController` successfully provisions a new lock, it calls `ref.read(trustedLocksNotifierProvider.notifier).refresh()`. This forces the notifier to re-read storage, causing the `MyKeysScreen` to instantly and smoothly re-render with the new lock card.

## 4. UI Local State
Ephemeral UI state (like `_isProcessing`, `_errorMessage`, or text field input) is kept purely local to standard `StatefulWidget` or `ConsumerStatefulWidget` instances. Riverpod is reserved strictly for global state, domain logic, and dependency injection.
