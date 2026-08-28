import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/session/trusted_locks_store.dart';
import 'fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage storage;
  late TrustedLocksStore store;

  setUp(() {
    storage = FakeFlutterSecureStorage();
    store = TrustedLocksStore(storage: storage);
  });

  group('TrustedLocksStore', () {
    test('getLockPublicKey returns null for unknown lock', () async {
      final key = await store.getLockPublicKey('unknown_lock');
      expect(key, isNull);
    });

    test('storeTrustedKey then getLockPublicKey returns it', () async {
      final dummyKey = Uint8List.fromList(List.generate(32, (i) => i));
      
      await store.storeTrustedKey('lock_1', dummyKey);
      final key = await store.getLockPublicKey('lock_1');
      
      expect(key, isNotNull);
      expect(key, equals(dummyKey));
    });

    test('removeTrustedKey then getLockPublicKey returns null', () async {
      final dummyKey = Uint8List.fromList(List.generate(32, (i) => i));
      
      await store.storeTrustedKey('lock_1', dummyKey);
      await store.removeTrustedKey('lock_1');
      
      final key = await store.getLockPublicKey('lock_1');
      expect(key, isNull);
    });

    test('listTrustedLocks returns all stored IDs', () async {
      final dummyKey = Uint8List.fromList(List.generate(32, (i) => i));
      
      await store.storeTrustedKey('lock_1', dummyKey);
      await store.storeTrustedKey('lock_2', dummyKey);
      
      final locks = await store.listTrustedLocks();
      expect(locks, unorderedEquals(['lock_1', 'lock_2']));
    });

    test('storeTrustedKey overwrites existing', () async {
      final key1 = Uint8List.fromList(List.generate(32, (i) => i));
      final key2 = Uint8List.fromList(List.generate(32, (i) => 255 - i));

      await store.storeTrustedKey('lock_1', key1);
      await store.storeTrustedKey('lock_1', key2);

      final key = await store.getLockPublicKey('lock_1');
      expect(key, equals(key2));
    });

    group('lock names', () {
      test('getLockName returns null when no name is set', () async {
        final name = await store.getLockName('lock_x');
        expect(name, isNull);
      });

      test('setLockName then getLockName round-trips', () async {
        await store.setLockName('lock_1', 'Front Door');
        final name = await store.getLockName('lock_1');
        expect(name, 'Front Door');
      });

      test('setLockName trims surrounding whitespace', () async {
        await store.setLockName('lock_1', '  Back Door  ');
        final name = await store.getLockName('lock_1');
        expect(name, 'Back Door');
      });

      test('setLockName with empty string removes any existing name', () async {
        await store.setLockName('lock_1', 'Front Door');
        await store.setLockName('lock_1', '   ');
        expect(await store.getLockName('lock_1'), isNull);
      });

      test('setLockName is a no-op when the trimmed name is unchanged', () async {
        await store.setLockName('lock_1', 'Front Door');
        await store.setLockName('lock_1', '  Front Door  ');
        final name = await store.getLockName('lock_1');
        expect(name, 'Front Door');
      });

      test('removeTrustedKey also drops the user-chosen name', () async {
        final dummyKey = Uint8List.fromList(List.generate(32, (i) => i));
        await store.storeTrustedKey('lock_1', dummyKey);
        await store.setLockName('lock_1', 'Front Door');

        await store.removeTrustedKey('lock_1');

        expect(await store.getLockName('lock_1'), isNull);
        expect(await store.getLockPublicKey('lock_1'), isNull);
      });

      test('names are isolated per lock', () async {
        await store.setLockName('lock_1', 'Front Door');
        await store.setLockName('lock_2', 'Back Door');

        expect(await store.getLockName('lock_1'), 'Front Door');
        expect(await store.getLockName('lock_2'), 'Back Door');
      });
    });
  });
}
