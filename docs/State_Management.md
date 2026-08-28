# State Management Architecture — Mobile Application Specification

This document specifies the state management architecture of the Smart Lock mobile application. It describes the dependency injection graph, the reactive state model, and the division of responsibility between global (Riverpod) state and ephemeral UI-local state.

---

## 1. Overview & Design Decisions

The application relies exclusively on **Riverpod** for compile-safe dependency injection and reactive state management.

**Design Decision: Why Riverpod?**
Passing domain controllers (`LockConnection`, `SessionController`) through the widget tree using `InheritedWidget` or manual constructor plumbing leads to boilerplate and brittle tests. Riverpod allows providers to be declared globally and resolved outside the widget tree, so domain logic can be instantiated and tested in pure Dart tests without spinning up the UI.

**Design Decision: Global vs. UI-local state.**
Riverpod is reserved strictly for global state, domain logic, and dependency injection. Ephemeral UI state (processing flags, error messages, text-field input) is kept local to `StatefulWidget` / `ConsumerStatefulWidget` instances.

---

## 2. Provider Scope

The entire application is wrapped in a `ProviderScope` at the root in [`lib/main.dart`](file:///workspaces/mobile_application/smartlock_application/lib/main.dart). This ensures a unified container for all singletons and state notifiers, and is the single point at which the widget tree is bound to the provider graph.

```
runApp(ProviderScope(child: App()))
```

The root widget [`App`](file:///workspaces/mobile_application/smartlock_application/lib/app/app.dart) builds a `MaterialApp` with light/dark `AppTheme`, named routes, and `onGenerateRoute`.

---

## 3. Dependency Injection Registry (`nfc_providers.dart`)

All providers are declared in [`lib/core/providers/nfc_providers.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/providers/nfc_providers.dart). This central registry guarantees every component operates on the exact same hardware bindings and cryptographic keystores.

### 3.1 Core Singletons

| Provider | Type | Purpose |
|---|---|---|
| `loggerProvider` | `Provider<Logger>` | Global logging instance (pretty-printer, no method count). |
| `nfcManagerProvider` | `Provider<NfcManager>` | The `NfcManager` singleton. |
| `isoDepTransportProvider` | `Provider<IsoDepTransport>` | Binds to `AndroidIsoDepTransport` (NFC hardware). |
| `storageProvider` | `Provider<FlutterSecureStorage>` | Hardware-backed keystore persistence. |
| `identityKeystoreProvider` | `Provider<IdentityKeystore>` | Phone's long-term Ed25519 identity. |
| `trustedLocksStoreProvider` | `Provider<TrustedLocksStore>` | Trusted lock public keys and user-chosen display names. |
| `themeModeProvider` | `StateNotifierProvider<ThemeModeNotifier, ThemeMode>` | User-selected theme mode. Persisted to `FlutterSecureStorage` under `theme_mode`; on first launch it falls back to the platform brightness (`WidgetsBinding.platformDispatcher.platformBrightness`). |

### 3.2 Domain Controllers

| Provider | Type | Purpose |
|---|---|---|
| `sessionControllerProvider` | `Provider<SessionController>` | Orchestrates the low-level handshake and APDU flow. |
| `lockConnectionProvider` | `Provider<LockConnection>` | Typed high-level commands (`unlock`, `lock`, `getStatus`, `revokeKey`). |
| `provisionControllerProvider` | `Provider<ProvisionController>` | Orchestrates the deferred-verification provisioning flow. |

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

final lockConnectionProvider = Provider<LockConnection>((ref) {
  return LockConnection(ref.watch(sessionControllerProvider));
});

final provisionControllerProvider = Provider<ProvisionController>((ref) {
  return ProvisionController(
    sessionController: ref.watch(sessionControllerProvider),
    identityKeystore: ref.watch(identityKeystoreProvider),
    trustedLocksStore: ref.watch(trustedLocksStoreProvider),
  );
});
```

### 3.3 Dependency Graph

```
storageProvider ──► identityKeystoreProvider
        │
        └────────► trustedLocksStoreProvider ──► trustedLocksNotifierProvider
                                  │
isoDepTransportProvider ──┐      │
                          ▼      ▼
              sessionControllerProvider
                          │
              ┌───────────┴────────────┐
              ▼                        ▼
   lockConnectionProvider    provisionControllerProvider
```

---

## 4. Reactive State (The `TrustedLocksNotifier`)

Data the UI must react to — the list of trusted locks — is managed via `StateNotifierProvider`.

### 4.1 `TrustedLocksNotifier`

Defined in [`nfc_providers.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/providers/nfc_providers.dart):

```dart
class TrustedLocksNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final TrustedLocksStore _store;

  TrustedLocksNotifier(this._store) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final locks = await _store.listTrustedLocks();
      state = AsyncValue.data(locks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> revokeKey(String lockId) async {
    try {
      await _store.removeTrustedKey(lockId);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final trustedLocksNotifierProvider =
    StateNotifierProvider<TrustedLocksNotifier, AsyncValue<List<String>>>((ref) {
  return TrustedLocksNotifier(ref.watch(trustedLocksStoreProvider));
});
```

### 4.2 State Shape & Transitions

The notifier exposes `AsyncValue<List<String>>` — a list of trusted lock IDs:

- **`loading`**: initial state, set on construction and at the start of every `refresh()`.
- **`data(locks)`**: the trusted lock IDs, re-read from `TrustedLocksStore` storage.
- **`error(e, st)`**: storage read/parse failures.

### 4.3 UI Consumption & Refresh Flow

- `MyKeysScreen` uses `ref.watch(trustedLocksNotifierProvider)` to build the lock-card list reactively.
- When provisioning succeeds, the UI calls `ref.read(trustedLocksNotifierProvider.notifier).refresh()`, forcing the notifier to re-read storage so the new lock appears immediately.
- When the user revokes a key, `TrustedLocksNotifier.revokeKey` removes it from the store and refreshes.

---

## 5. UI Local State

Ephemeral UI state is kept purely local to widget state objects:

- **`_ActuateLockScreenState`**: `_isActuating`, `_errorMessage`, `_success` — drive the actuation visualization and button states.
- **`_Step3NfcSyncScreenState`**: `_isProvisioning`, `_errorMessage` — drive the provisioning progress UI.
- **`_Step2ScanQrScreenState`**: `_isProcessing` — debounces repeated QR detections.

These are deliberately *not* hoisted into Riverpod: they are single-screen, short-lived, and have no consumers outside the owning widget.

---

## 6. Testing Strategy

The separation between providers and pure domain classes makes testing straightforward:

- **Pure Dart tests** construct `SessionController`, `LockConnection`, and `ProvisionController` directly with a `FakeIsoDepTransport` and a `FakeFlutterSecureStorage`, with no widget tree.
- **The provider graph** is verified implicitly by construction (Riverpod fails at compile time on type mismatches).
- The full provisioning → unlock cycle is exercised end-to-end in `test/features/session/integration/full_session_test.dart` against a simulated lock that implements the wire protocol.
