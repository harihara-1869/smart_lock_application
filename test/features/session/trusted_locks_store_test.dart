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
  });
}
