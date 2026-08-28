import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:logger/logger.dart';

import 'package:smartlock_application/core/nfc_transport/iso_dep_transport.dart';
import 'package:smartlock_application/core/nfc_transport/android_iso_dep_transport.dart';
import 'package:smartlock_application/features/session/identity_keystore.dart';
import 'package:smartlock_application/features/session/trusted_locks_store.dart';
import 'package:smartlock_application/features/session/session_controller.dart';
import 'package:smartlock_application/features/session/facade/lock_connection.dart';
import 'package:smartlock_application/features/session/provisioning/provision_controller.dart';

final loggerProvider = Provider<Logger>((ref) {
  return Logger(printer: PrettyPrinter(methodCount: 0));
});

final nfcManagerProvider = Provider<NfcManager>((ref) {
  return NfcManager.instance;
});

final isoDepTransportProvider = Provider<IsoDepTransport>((ref) {
  final logger = ref.watch(loggerProvider);
  return AndroidIsoDepTransport(logger: logger);
});

final storageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// The provisioning secret (32 bytes) scanned in step 2 and consumed in
/// step 3. Held in a scoped notifier rather than passed through the
/// navigator's route arguments, so the routing layer never owns the secret
/// and a wrong-typed push can't crash step 3.
class ProvisionSecretNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;

  void set(Uint8List secret) => state = secret;

  void clear() => state = null;
}

final provisionSecretProvider =
    NotifierProvider<ProvisionSecretNotifier, Uint8List?>(
  ProvisionSecretNotifier.new,
);

final identityKeystoreProvider = Provider<IdentityKeystore>((ref) {
  return IdentityKeystore(storage: ref.watch(storageProvider));
});

final trustedLocksStoreProvider = Provider<TrustedLocksStore>((ref) {
  return TrustedLocksStore(storage: ref.watch(storageProvider));
});

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

final trustedLocksNotifierProvider = StateNotifierProvider<TrustedLocksNotifier, AsyncValue<List<String>>>((ref) {
  return TrustedLocksNotifier(ref.watch(trustedLocksStoreProvider));
});

/// Persists the user's chosen [ThemeMode] in [FlutterSecureStorage] so the
/// app reopens in the last-selected theme. On first launch (no value stored),
/// it falls back to the platform's current brightness, so a phone set to
/// light mode opens in light, and a phone set to dark mode opens in dark.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _storageKey = 'theme_mode';

  final FlutterSecureStorage _storage;

  ThemeModeNotifier(this._storage) : super(_initialMode()) {
    _loadPersistedMode();
  }

  static ThemeMode _initialMode() {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return platformBrightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> _loadPersistedMode() async {
    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored == null) return;
      final parsed = _decode(stored);
      if (parsed != null) state = parsed;
    } catch (_) {
      // Ignore read errors and keep the platform-derived default.
    }
  }

  void toggleTheme() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    _persist(next);
  }

  void setMode(ThemeMode mode) {
    if (mode == state) return;
    state = mode;
    _persist(mode);
  }

  void _persist(ThemeMode mode) {
    _storage.write(key: _storageKey, value: _encode(mode));
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode? _decode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(storageProvider));
});
