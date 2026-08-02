import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/session/identity_keystore.dart';
import 'fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage storage;
  late IdentityKeystore keystore;

  setUp(() {
    storage = FakeFlutterSecureStorage();
    keystore = IdentityKeystore(storage: storage);
  });

  group('IdentityKeystore', () {
    test('getOrCreateIdentity creates on first call', () async {
      final identity = await keystore.getOrCreateIdentity();
      expect(identity.seed.length, 32);
      expect(identity.publicKey.length, 32);
      
      final hasIdentity = await keystore.hasIdentity();
      expect(hasIdentity, isTrue);
    });

    test('getOrCreateIdentity returns same on second call', () async {
      final identity1 = await keystore.getOrCreateIdentity();
      final identity2 = await keystore.getOrCreateIdentity();
      
      expect(identity1.seed, equals(identity2.seed));
      expect(identity1.publicKey, equals(identity2.publicKey));
    });

    test('deleteIdentity then getOrCreateIdentity creates new', () async {
      final identity1 = await keystore.getOrCreateIdentity();
      await keystore.deleteIdentity();
      
      final hasIdentity = await keystore.hasIdentity();
      expect(hasIdentity, isFalse);
      
      final identity2 = await keystore.getOrCreateIdentity();
      
      expect(identity1.seed, isNot(equals(identity2.seed)));
      expect(identity1.publicKey, isNot(equals(identity2.publicKey)));
    });
  });
}
