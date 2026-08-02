import 'dart:typed_data';

/// Parses the lock's provisioning QR code.
///
/// QR contains ONLY a 64-character uppercase hex string = 32-byte Provision Secret.
/// NO lock ID, NO lock public key, NO URL scheme.
/// Source: APP_Development.md §5 (Q8).
abstract final class QrProvisionParser {
  /// Parse a raw QR string into a 32-byte Provision Secret.
  /// Returns null if the QR data is not exactly 64 hex characters.
  static Uint8List? parse(String rawQrData) {
    final trimmed = rawQrData.trim();
    if (trimmed.length != 64) {
      return null;
    }
    
    // Check if it's all valid hex characters
    final hexRegExp = RegExp(r'^[0-9a-fA-F]+$');
    if (!hexRegExp.hasMatch(trimmed)) {
      return null;
    }

    try {
      final result = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        result[i] = int.parse(trimmed.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}
