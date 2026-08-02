import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartlock_application/features/session/crypto/crypto_primitives.dart';


/// Manages the phone's own Ed25519 long-term identity keypair.
///
/// Stored in flutter_secure_storage. Generated once on first launch.
/// The 32-byte seed is the secret; the 32-byte public key is derived from it.
class IdentityKeystore {
  final FlutterSecureStorage _storage;

  static const _seedKey = 'identity_ed25519_seed';
  static const _pubKeyKey = 'identity_ed25519_pubkey';

  IdentityKeystore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Get or generate the phone's identity keypair.
  /// First call generates and persists; subsequent calls read from storage.
  Future<({Uint8List seed, Uint8List publicKey})> getOrCreateIdentity() async {
    final seedHex = await _storage.read(key: _seedKey);
    final pubKeyHex = await _storage.read(key: _pubKeyKey);

    if (seedHex != null && pubKeyHex != null) {
      return (
        seed: _decodeHex(seedHex),
        publicKey: _decodeHex(pubKeyHex),
      );
    }

    final kp = await CryptoPrimitives.generateEd25519KeyPair();
    await _storage.write(key: _seedKey, value: _encodeHex(kp.privateKey));
    await _storage.write(key: _pubKeyKey, value: _encodeHex(kp.publicKey));

    return (
      seed: kp.privateKey,
      publicKey: kp.publicKey,
    );
  }

  /// Check if an identity exists without creating one.
  Future<bool> hasIdentity() async {
    return await _storage.containsKey(key: _seedKey);
  }

  /// Delete the identity (for testing / factory reset).
  Future<void> deleteIdentity() async {
    await _storage.delete(key: _seedKey);
    await _storage.delete(key: _pubKeyKey);
  }

  static String _encodeHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  static Uint8List _decodeHex(String hexString) {
    final result = Uint8List(hexString.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hexString.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
