import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores trusted lock identities: NFC UID → lock's Ed25519 public key,
/// and a separate map of user-chosen display names (NFC UID → name).
///
/// Populated by provisioning (Phase 8). Used by SessionController to look up
/// the lock's public key for M2 signature verification. Lock names are
/// user-editable from the Actuate Lock and My Keys screens.
class TrustedLocksStore {
  final FlutterSecureStorage _storage;

  static const _storeKey = 'trusted_locks_json';
  static const _namesKey = 'lock_names_json';

  /// Maximum allowed length for a user-supplied lock name.
  static const maxNameLength = 40;

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

  /// Remove a lock from the trusted store. Also drops any user-assigned
  /// name for the same lock, so a future re-provision with the same UID
  /// does not inherit a stale alias.
  Future<void> removeTrustedKey(String lockId) async {
    final map = await _readMap();
    final names = await _readNamesMap();
    var changed = false;
    if (map.remove(lockId) != null) changed = true;
    if (names.remove(lockId) != null) changed = true;
    if (changed) {
      await _writeMap(map);
      await _writeNamesMap(names);
    }
  }

  /// List all trusted lock IDs.
  Future<List<String>> listTrustedLocks() async {
    final map = await _readMap();
    return map.keys.toList();
  }

  /// Get the user-chosen display name for a lock, or null if none is set.
  Future<String?> getLockName(String lockId) async {
    final map = await _readNamesMap();
    return map[lockId];
  }

  /// Persist a user-chosen display name for a lock. Empty or whitespace-only
  /// names remove any existing entry (i.e. revert to showing the lock ID).
  Future<void> setLockName(String lockId, String name) async {
    final trimmed = name.trim();
    final map = await _readNamesMap();
    if (trimmed.isEmpty) {
      if (map.remove(lockId) != null) {
        await _writeNamesMap(map);
      }
      return;
    }
    if (map[lockId] == trimmed) return;
    map[lockId] = trimmed;
    await _writeNamesMap(map);
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

  Future<Map<String, String>> _readNamesMap() async {
    final jsonString = await _storage.read(key: _namesKey);
    if (jsonString == null) return {};
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeNamesMap(Map<String, String> map) async {
    final jsonString = jsonEncode(map);
    await _storage.write(key: _namesKey, value: jsonString);
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
