import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';
import 'package:smartlock_application/features/session/crypto/crypto_primitives.dart';
import 'package:smartlock_application/features/session/secure_channel.dart';

/// Unwrap a [Result], failing the test with [message] on [Err].
T _unwrap<T, E>(Result<T, E> result, String message) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final error) => fail('$message: $error'),
  };
}

void main() {
  // Default channel uses a single key for both directions so that encrypt→decrypt
  // round-trips succeed. The SecureChannel is directional (encrypt uses K_p2e,
  // decrypt uses K_e2p) and they are distinct keys in production — tests that
  // need to PROVE directionality (2, 7) build their own channels with distinct
  // keys instead of using this helper.
  SecureChannel _buildChannel() {
    final key = CryptoPrimitives.generateSecureRandom(32);
    return SecureChannel(kP2E: key, kE2P: key);
  }

  group('SecureChannel.encrypt/decrypt', () {
    test('encrypt then decrypt round-trip', () async {
      final channel = _buildChannel();
      final plaintext = Uint8List.fromList([0x02]); // CMD_UNLOCK

      final encrypted = _unwrap(
        await channel.encrypt(plaintext),
        'encrypt should succeed',
      );
      final decrypted = _unwrap(
        await channel.decrypt(encrypted),
        'decrypt should succeed',
      );

      expect(decrypted, orderedEquals(plaintext));
    });

    test('encrypt uses K_p2e, decrypt uses K_e2p', () async {
      final kP2E = CryptoPrimitives.generateSecureRandom(32);
      final kE2P = CryptoPrimitives.generateSecureRandom(32);
      final channel = SecureChannel(kP2E: kP2E, kE2P: kE2P);
      final plaintext = Uint8List.fromList([0x04]); // CMD_GET_STATUS

      // Encrypt via the channel (must use K_p2e), then manually decrypt with
      // K_p2e directly — proves the channel encrypts with the phone→lock key.
      final encrypted = _unwrap(
        await channel.encrypt(plaintext),
        'encrypt should succeed',
      );
      final manualDecrypt = await CryptoPrimitives.aesGcmDecrypt(
        key: kP2E,
        encryptedPayload: encrypted,
      );
      expect(manualDecrypt, orderedEquals(plaintext));

      // Reverse: manually encrypt with K_e2p (the lock→phone key), then decrypt
      // via the channel — proves the channel decrypts with K_e2p.
      final manualEncrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: kE2P,
        plaintext: plaintext,
      );
      final channelDecrypted = _unwrap(
        await channel.decrypt(manualEncrypted),
        'decrypt should succeed',
      );
      expect(channelDecrypted, orderedEquals(plaintext));
    });

    test('encrypt rejects plaintext > 199 bytes', () async {
      final channel = _buildChannel();
      final tooLarge =
          CryptoPrimitives.generateSecureRandom(200); // 199 + 1

      final result = await channel.encrypt(tooLarge);

      expect(result, isA<Err<Uint8List, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcPayloadTooLarge>());
          switch (error) {
            case NfcPayloadTooLarge(:final size, :final maxSize):
              expect(size, 200);
              expect(maxSize, ProtocolConstants.maxSecurePlaintext);
            case _:
              fail('Unexpected error variant: $error');
          }
        case Ok(:final value):
          fail('Expected Err, got Ok: $value');
      }
    });

    test('encrypt accepts exactly 199 bytes', () async {
      final channel = _buildChannel();
      final maxPlaintext =
          CryptoPrimitives.generateSecureRandom(199);

      final encrypted = _unwrap(
        await channel.encrypt(maxPlaintext),
        'encrypt should succeed at the limit',
      );

      // nonce(12) + ciphertext(199) + tag(16) = 227 = transportMaxLc
      expect(encrypted.length, ProtocolConstants.transportMaxLc);
    });

    test('encrypt accepts empty plaintext', () async {
      final channel = _buildChannel();

      final encrypted = _unwrap(
        await channel.encrypt(Uint8List(0)),
        'encrypt should succeed on empty input',
      );

      // nonce(12) + ciphertext(0) + tag(16) = 28 bytes
      expect(encrypted.length, 28);
    });

    test('decrypt fails on tampered ciphertext', () async {
      final channel = _buildChannel();
      final plaintext = Uint8List.fromList([0x01, 0x02, 0x03]);

      final encrypted = _unwrap(
        await channel.encrypt(plaintext),
        'encrypt should succeed',
      );

      // Flip a ciphertext byte (after the 12-byte nonce).
      encrypted[13] ^= 0xFF;

      final result = await channel.decrypt(encrypted);

      expect(result, isA<Err<Uint8List, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcDecryptionFailed>());
        case Ok(:final value):
          fail('Expected Err, got Ok: $value');
      }
    });

    test('decrypt fails with wrong key', () async {
      // Encrypt with one key, decrypt via a channel built with a different key.
      final encryptKey = CryptoPrimitives.generateSecureRandom(32);
      final otherKey = CryptoPrimitives.generateSecureRandom(32);
      final plaintext = Uint8List.fromList([0xAA, 0xBB]);

      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: encryptKey,
        plaintext: plaintext,
      );

      final channel = SecureChannel(
        kP2E: otherKey,
        kE2P: otherKey, // != encryptKey → tag won't verify
      );

      final result = await channel.decrypt(encrypted);

      expect(result, isA<Err<Uint8List, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcDecryptionFailed>());
        case Ok(:final value):
          fail('Expected Err, got Ok: $value');
      }
    });
  });
}
