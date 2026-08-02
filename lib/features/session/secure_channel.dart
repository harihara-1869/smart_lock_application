import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';
import 'package:smartlock_application/features/session/crypto/crypto_primitives.dart';

/// Encrypts/decrypts application payloads within an established SLOCK-HS-v1
/// session.
///
/// NOT responsible for the handshake, NFC I/O, or transport state management.
/// Constructed with the two directional session keys derived at M3 and reused
/// until the session ends:
/// - [kP2E] encrypts phone→lock commands.
/// - [kE2P] decrypts lock→phone responses.
///
/// All ciphertext uses the AES-256-GCM wire format
/// `nonce(12) ‖ ciphertext ‖ tag(16)` with empty AAD (master §7.3).
class SecureChannel {
  final Uint8List _kP2E; // 32-byte key: phone → lock
  final Uint8List _kE2P; // 32-byte key: lock → phone

  SecureChannel({required Uint8List kP2E, required Uint8List kE2P})
      : _kP2E = kP2E,
        _kE2P = kE2P;

  /// Encrypt a plaintext command (phone → lock).
  ///
  /// Returns the wire-format bytes: `nonce(12) ‖ ciphertext ‖ tag(16)`.
  /// Fails with [NfcSessionError.payloadTooLarge] if [plaintext] exceeds
  /// the 199-byte protocol limit.
  Future<Result<Uint8List, NfcSessionError>> encrypt(
    Uint8List plaintext,
  ) async {
    if (plaintext.length > ProtocolConstants.maxSecurePlaintext) {
      return Result.err(
        NfcSessionError.payloadTooLarge(
          plaintext.length,
          ProtocolConstants.maxSecurePlaintext,
        ),
      );
    }

    final encrypted = await CryptoPrimitives.aesGcmEncrypt(
      key: _kP2E,
      plaintext: plaintext,
    );
    return Result.ok(encrypted);
  }

  /// Decrypt a response payload (lock → phone).
  ///
  /// [encryptedPayload] is the wire-format bytes
  /// `nonce(12) ‖ ciphertext ‖ tag(16)`.
  /// Returns the plaintext on success, or [NfcSessionError.decryptionFailed]
  /// on a GCM tag mismatch (the session is dead — do not retry with the same
  /// keys).
  Future<Result<Uint8List, NfcSessionError>> decrypt(
    Uint8List encryptedPayload,
  ) async {
    try {
      final plaintext = await CryptoPrimitives.aesGcmDecrypt(
        key: _kE2P,
        encryptedPayload: encryptedPayload,
      );
      return Result.ok(plaintext);
    } on SecretBoxAuthenticationError {
      return const Result.err(NfcSessionError.decryptionFailed());
    }
  }
}
