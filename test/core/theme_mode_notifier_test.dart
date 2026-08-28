import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import '../features/session/fake_flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeNotifier', () {
    late FakeFlutterSecureStorage storage;

    setUp(() {
      storage = FakeFlutterSecureStorage();
    });

    test('defaults to platform brightness on first launch (light)', () async {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .platformBrightnessTestValue = Brightness.light;

      final notifier = ThemeModeNotifier(storage);
      // Yield once so the async _loadPersistedMode() runs to completion.
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, ThemeMode.light);
    });

    test('defaults to platform brightness on first launch (dark)', () async {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .platformBrightnessTestValue = Brightness.dark;

      final notifier = ThemeModeNotifier(storage);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, ThemeMode.dark);
    });

    test('restores persisted mode on subsequent launches', () async {
      await storage.write(key: 'theme_mode', value: 'light');

      final notifier = ThemeModeNotifier(storage);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, ThemeMode.light);
    });

    test('toggleTheme flips state and persists it', () async {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .platformBrightnessTestValue = Brightness.dark;
      final notifier = ThemeModeNotifier(storage);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, ThemeMode.dark);

      notifier.toggleTheme();
      expect(notifier.state, ThemeMode.light);
      expect(await storage.read(key: 'theme_mode'), 'light');

      notifier.toggleTheme();
      expect(notifier.state, ThemeMode.dark);
      expect(await storage.read(key: 'theme_mode'), 'dark');
    });

    test('setMode persists the new value', () async {
      final notifier = ThemeModeNotifier(storage);
      await Future<void>.delayed(Duration.zero);

      notifier.setMode(ThemeMode.system);
      expect(notifier.state, ThemeMode.system);
      expect(await storage.read(key: 'theme_mode'), 'system');
    });

    test('setMode is a no-op when the mode is unchanged', () async {
      await storage.write(key: 'theme_mode', value: 'light');
      final notifier = ThemeModeNotifier(storage);
      await Future<void>.delayed(Duration.zero);

      // Overwrite the storage to detect any (incorrect) re-write.
      await storage.write(key: 'theme_mode', value: 'light');
      notifier.setMode(ThemeMode.light);
      expect(await storage.read(key: 'theme_mode'), 'light');
    });

    test('ignores unrecognized stored values', () async {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .platformBrightnessTestValue = Brightness.dark;
      await storage.write(key: 'theme_mode', value: 'mauve');

      final notifier = ThemeModeNotifier(storage);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, ThemeMode.dark);
    });
  });
}
