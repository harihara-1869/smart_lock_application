import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores trusted lock identities: NFC UID → lock's Ed25519 public key.
///
/// Populated by provisioning (Phase 8). Used by SessionController to look up
/// the lock's public key for M2 signature verification.
class TrustedLocksStore {
  final FlutterSecureStorage _storage;

  static const _storeKey = 'trusted_locks_json';

  TrustedLocksStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Get lock's Ed25519 public key by lock ID.
  /// Returns null if no trusted key is stored for this lock.
  Future<Uint8List?> getLockPublicKey(String lockId) async {
    final map = await _readMap();
    final hexString = map[lockId];
    if (hexString == null) return null;
    return _decodeHex(hexString);
  }

  /// Store a lock's Ed25519 public key after successful provisioning.
  Future<void> storeTrustedKey(String lockId, Uint8List lockPublicKey) async {
    final map = await _readMap();
    map[lockId] = _encodeHex(lockPublicKey);
    await _writeMap(map);
  }

  /// Remove a lock from the trusted store.
  Future<void> removeTrustedKey(String lockId) async {
    final map = await _readMap();
    if (map.containsKey(lockId)) {
      map.remove(lockId);
      await _writeMap(map);
    }
  }

  /// List all trusted lock IDs.
  Future<List<String>> listTrustedLocks() async {
    final map = await _readMap();
    return map.keys.toList();
  }

  Future<Map<String, String>> _readMap() async {
    final jsonString = await _storage.read(key: _storeKey);
    if (jsonString == null) return {};
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMap(Map<String, String> map) async {
    final jsonString = jsonEncode(map);
    await _storage.write(key: _storeKey, value: jsonString);
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
