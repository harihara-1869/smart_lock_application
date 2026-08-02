import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';
import 'package:smartlock_application/features/session/crypto/crypto_primitives.dart';

/// Helper: hex string → Uint8List.
Uint8List _hex(String hex) {
  hex = hex.replaceAll(' ', '').replaceAll('\n', '');
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Helper: Uint8List → hex string.
String _toHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  // ==========================================================================
  // X25519
  // ==========================================================================
  group('CryptoPrimitives.X25519', () {
    test('generateX25519KeyPair returns 32-byte keys', () async {
      final kp = await CryptoPrimitives.generateX25519KeyPair();
      expect(kp.privateKey.length, 32);
      expect(kp.publicKey.length, 32);
    });

    test('two generated keypairs are distinct', () async {
      final kp1 = await CryptoPrimitives.generateX25519KeyPair();
      final kp2 = await CryptoPrimitives.generateX25519KeyPair();
      expect(kp1.publicKey, isNot(orderedEquals(kp2.publicKey)));
    });

    test('x25519KeyPairFromSeed is deterministic', () async {
      final seed = _hex(
        '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a',
      );
      final kp1 = await CryptoPrimitives.x25519KeyPairFromSeed(seed);
      final kp2 = await CryptoPrimitives.x25519KeyPairFromSeed(seed);
      expect(kp1.publicKey, orderedEquals(kp2.publicKey));
    });

    // RFC 7748 §6.1 — X25519 test vector
    test('shared secret matches RFC 7748 §6.1 test vector', () async {
      // Alice's private key (scalar)
      final aliceSk = _hex(
        '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a',
      );
      // Bob's private key (scalar)
      final bobSk = _hex(
        '5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb',
      );

      final aliceKp = await CryptoPrimitives.x25519KeyPairFromSeed(aliceSk);
      final bobKp = await CryptoPrimitives.x25519KeyPairFromSeed(bobSk);

      // RFC 7748 §6.1 expected public keys
      expect(
        _toHex(aliceKp.publicKey),
        '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a',
      );
      expect(
        _toHex(bobKp.publicKey),
        'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f',
      );

      // Shared secret: both sides compute the same value.
      final ssAlice = await CryptoPrimitives.x25519SharedSecret(
        localPrivateKey: aliceSk,
        remotePublicKey: bobKp.publicKey,
      );
      final ssBob = await CryptoPrimitives.x25519SharedSecret(
        localPrivateKey: bobSk,
        remotePublicKey: aliceKp.publicKey,
      );

      expect(ssAlice, orderedEquals(ssBob));
      expect(ssAlice.length, 32);

      // RFC 7748 §6.1 expected shared secret
      expect(
        _toHex(ssAlice),
        '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742',
      );
    });
  });

  // ==========================================================================
  // Ed25519
  // ==========================================================================
  group('CryptoPrimitives.Ed25519', () {
    test('generateEd25519KeyPair returns correct key lengths', () async {
      final kp = await CryptoPrimitives.generateEd25519KeyPair();
      // The `cryptography` package's Ed25519 private key is the raw 32-byte
      // seed. The firmware's 64-byte format (seed 32B ‖ public 32B) is
      // composed at the IdentityKeystore layer, not here.
      expect(kp.privateKey.length, 32);
      expect(kp.publicKey.length, 32);
    });

    test('ed25519KeyPairFromSeed is deterministic', () async {
      final seed = Uint8List(32); // all zeros
      final kp1 = await CryptoPrimitives.ed25519KeyPairFromSeed(seed);
      final kp2 = await CryptoPrimitives.ed25519KeyPairFromSeed(seed);
      expect(kp1.publicKey, orderedEquals(kp2.publicKey));
      expect(kp1.privateKey, orderedEquals(kp2.privateKey));
    });

    test('sign then verify round-trip succeeds', () async {
      final kp = await CryptoPrimitives.generateEd25519KeyPair();
      final message = utf8.encode('SLOCK-HS-v1 test message');

      final sig = await CryptoPrimitives.ed25519Sign(
        message: Uint8List.fromList(message),
        privateKey: kp.privateKey,
        publicKey: kp.publicKey,
      );

      expect(sig.length, 64);

      final valid = await CryptoPrimitives.ed25519Verify(
        message: Uint8List.fromList(message),
        signatureBytes: sig,
        publicKey: kp.publicKey,
      );

      expect(valid, isTrue);
    });

    test('verify rejects tampered message', () async {
      final kp = await CryptoPrimitives.generateEd25519KeyPair();
      final message = Uint8List.fromList(utf8.encode('original'));

      final sig = await CryptoPrimitives.ed25519Sign(
        message: message,
        privateKey: kp.privateKey,
        publicKey: kp.publicKey,
      );

      final tampered = Uint8List.fromList(utf8.encode('tampered'));
      final valid = await CryptoPrimitives.ed25519Verify(
        message: tampered,
        signatureBytes: sig,
        publicKey: kp.publicKey,
      );

      expect(valid, isFalse);
    });

    test('verify rejects wrong public key', () async {
      final kp1 = await CryptoPrimitives.generateEd25519KeyPair();
      final kp2 = await CryptoPrimitives.generateEd25519KeyPair();
      final message = Uint8List.fromList([1, 2, 3]);

      final sig = await CryptoPrimitives.ed25519Sign(
        message: message,
        privateKey: kp1.privateKey,
        publicKey: kp1.publicKey,
      );

      final valid = await CryptoPrimitives.ed25519Verify(
        message: message,
        signatureBytes: sig,
        publicKey: kp2.publicKey, // Wrong key
      );

      expect(valid, isFalse);
    });

    test('verify rejects tampered signature', () async {
      final kp = await CryptoPrimitives.generateEd25519KeyPair();
      final message = Uint8List.fromList([42]);

      final sig = await CryptoPrimitives.ed25519Sign(
        message: message,
        privateKey: kp.privateKey,
        publicKey: kp.publicKey,
      );

      // Flip a bit in the signature
      sig[0] ^= 0x01;

      final valid = await CryptoPrimitives.ed25519Verify(
        message: message,
        signatureBytes: sig,
        publicKey: kp.publicKey,
      );

      expect(valid, isFalse);
    });
  });

  // ==========================================================================
  // HKDF-SHA256
  // ==========================================================================
  group('CryptoPrimitives.HKDF', () {
    // RFC 5869 Test Case 1
    test('hkdfDerive matches RFC 5869 Test Case 1', () async {
      final ikm = _hex('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
      final salt = _hex('000102030405060708090a0b0c');
      final info = _hex('f0f1f2f3f4f5f6f7f8f9');

      final okm = await CryptoPrimitives.hkdfDerive(
        ikm: ikm,
        salt: salt,
        info: info,
        outputLength: 42,
      );

      expect(
        _toHex(okm),
        '3cb25f25faacd57a90434f64d0362f2a'
        '2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
        '34007208d5b887185865',
      );
    });

    // RFC 5869 Test Case 2
    test('hkdfDerive matches RFC 5869 Test Case 2', () async {
      final ikm = _hex(
        '000102030405060708090a0b0c0d0e0f'
        '101112131415161718191a1b1c1d1e1f'
        '202122232425262728292a2b2c2d2e2f'
        '303132333435363738393a3b3c3d3e3f'
        '404142434445464748494a4b4c4d4e4f',
      );
      final salt = _hex(
        '606162636465666768696a6b6c6d6e6f'
        '707172737475767778797a7b7c7d7e7f'
        '808182838485868788898a8b8c8d8e8f'
        '909192939495969798999a9b9c9d9e9f'
        'a0a1a2a3a4a5a6a7a8a9aaabacadaeaf',
      );
      final info = _hex(
        'b0b1b2b3b4b5b6b7b8b9babbbcbdbebf'
        'c0c1c2c3c4c5c6c7c8c9cacbcccdcecf'
        'd0d1d2d3d4d5d6d7d8d9dadbdcdddedf'
        'e0e1e2e3e4e5e6e7e8e9eaebecedeeef'
        'f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff',
      );

      final okm = await CryptoPrimitives.hkdfDerive(
        ikm: ikm,
        salt: salt,
        info: info,
        outputLength: 82,
      );

      expect(
        _toHex(okm),
        'b11e398dc80327a1c8e7f78c596a4934'
        '4f012eda2d4efad8a050cc4c19afa97c'
        '59045a99cac7827271cb41c65e590e09'
        'da3275600c2f09b8367793a9aca3db71'
        'cc30c58179ec3e87c14c01d5c1f3434f'
        '1d87',
      );
    });

    // RFC 5869 Test Case 3 — zero-length salt and info
    test('hkdfDerive matches RFC 5869 Test Case 3 (empty salt+info)', () async {
      final ikm = _hex('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
      final salt = Uint8List(0);
      final info = Uint8List(0);

      final okm = await CryptoPrimitives.hkdfDerive(
        ikm: ikm,
        salt: salt,
        info: info,
        outputLength: 42,
      );

      expect(
        _toHex(okm),
        '8da4e775a563c18f715f802a063c5a31'
        'b8a11f5c5ee1879ec3454e5f3c738d2d'
        '9d201395faa4b61a96c8',
      );
    });

    test('deriveSessionKeys produces two distinct 32-byte keys', () async {
      final sharedSecret = Uint8List(32)..fillRange(0, 32, 0xAA);
      final challengeP = Uint8List(32)..fillRange(0, 32, 0xBB);
      final challengeL = Uint8List(32)..fillRange(0, 32, 0xCC);

      final keys = await CryptoPrimitives.deriveSessionKeys(
        sharedSecret: sharedSecret,
        challengeP: challengeP,
        challengeL: challengeL,
      );

      expect(keys.phoneToEsp.length, 32);
      expect(keys.espToPhone.length, 32);
      expect(keys.phoneToEsp, isNot(orderedEquals(keys.espToPhone)));
    });

    test('deriveSessionKeys is deterministic', () async {
      final sharedSecret = Uint8List(32)..fillRange(0, 32, 0x11);
      final challengeP = Uint8List(32)..fillRange(0, 32, 0x22);
      final challengeL = Uint8List(32)..fillRange(0, 32, 0x33);

      final keys1 = await CryptoPrimitives.deriveSessionKeys(
        sharedSecret: sharedSecret,
        challengeP: challengeP,
        challengeL: challengeL,
      );
      final keys2 = await CryptoPrimitives.deriveSessionKeys(
        sharedSecret: sharedSecret,
        challengeP: challengeP,
        challengeL: challengeL,
      );

      expect(keys1.phoneToEsp, orderedEquals(keys2.phoneToEsp));
      expect(keys1.espToPhone, orderedEquals(keys2.espToPhone));
    });
  });

  // ==========================================================================
  // AES-256-GCM
  // ==========================================================================
  group('CryptoPrimitives.AES-256-GCM', () {
    test('encrypt then decrypt round-trip succeeds', () async {
      final key = CryptoPrimitives.generateSecureRandom(32);
      final plaintext = Uint8List.fromList(utf8.encode('Hello, lock!'));

      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: key,
        plaintext: plaintext,
      );

      // Wire format: nonce(12) + ciphertext(12) + tag(16) = 40 bytes
      expect(encrypted.length, 12 + plaintext.length + 16);

      final decrypted = await CryptoPrimitives.aesGcmDecrypt(
        key: key,
        encryptedPayload: encrypted,
      );

      expect(decrypted, orderedEquals(plaintext));
    });

    test('encrypt with explicit nonce produces deterministic output', () async {
      final key = Uint8List(32)..fillRange(0, 32, 0x42);
      final nonce = Uint8List(12)..fillRange(0, 12, 0x01);
      final plaintext = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);

      final enc1 = await CryptoPrimitives.aesGcmEncrypt(
        key: key,
        plaintext: plaintext,
        nonce: nonce,
      );
      final enc2 = await CryptoPrimitives.aesGcmEncrypt(
        key: key,
        plaintext: plaintext,
        nonce: nonce,
      );

      expect(enc1, orderedEquals(enc2));
    });

    test('decrypt fails with wrong key', () async {
      final key1 = Uint8List(32)..fillRange(0, 32, 0x01);
      final key2 = Uint8List(32)..fillRange(0, 32, 0x02);
      final plaintext = Uint8List.fromList([1, 2, 3]);

      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: key1,
        plaintext: plaintext,
      );

      expect(
        () => CryptoPrimitives.aesGcmDecrypt(
          key: key2,
          encryptedPayload: encrypted,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('decrypt fails with tampered ciphertext', () async {
      final key = CryptoPrimitives.generateSecureRandom(32);
      final plaintext = Uint8List.fromList([0xAA, 0xBB]);

      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: key,
        plaintext: plaintext,
      );

      // Tamper with a ciphertext byte (after the 12-byte nonce)
      encrypted[13] ^= 0xFF;

      expect(
        () => CryptoPrimitives.aesGcmDecrypt(
          key: key,
          encryptedPayload: encrypted,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('decrypt fails with tampered tag', () async {
      final key = CryptoPrimitives.generateSecureRandom(32);
      final plaintext = Uint8List.fromList([0x01]);

      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: key,
        plaintext: plaintext,
      );

      // Tamper with the last byte (part of the tag)
      encrypted[encrypted.length - 1] ^= 0x01;

      expect(
        () => CryptoPrimitives.aesGcmDecrypt(
          key: key,
          encryptedPayload: encrypted,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('empty plaintext round-trip works', () async {
      final key = CryptoPrimitives.generateSecureRandom(32);
      final plaintext = Uint8List(0);

      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: key,
        plaintext: plaintext,
      );

      // nonce(12) + ciphertext(0) + tag(16) = 28 bytes
      expect(encrypted.length, 28);

      final decrypted = await CryptoPrimitives.aesGcmDecrypt(
        key: key,
        encryptedPayload: encrypted,
      );

      expect(decrypted, isEmpty);
    });

    test('max protocol plaintext (199 bytes) round-trips', () async {
      final key = CryptoPrimitives.generateSecureRandom(32);
      final plaintext = CryptoPrimitives.generateSecureRandom(
        ProtocolConstants.maxSecurePlaintext,
      );

      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: key,
        plaintext: plaintext,
      );

      // nonce(12) + ciphertext(199) + tag(16) = 227 = transportMaxLc
      expect(encrypted.length, ProtocolConstants.transportMaxLc);

      final decrypted = await CryptoPrimitives.aesGcmDecrypt(
        key: key,
        encryptedPayload: encrypted,
      );

      expect(decrypted, orderedEquals(plaintext));
    });

    test('wire format is nonce ‖ ciphertext ‖ tag', () async {
      final key = Uint8List(32)..fillRange(0, 32, 0xFF);
      final nonce = Uint8List(12)..fillRange(0, 12, 0xAA);
      final plaintext = Uint8List.fromList([0x01, 0x02]);

      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: key,
        plaintext: plaintext,
        nonce: nonce,
      );

      // First 12 bytes should be the nonce
      expect(
        encrypted.sublist(0, 12),
        orderedEquals(nonce),
      );

      // Total length should be 12 + 2 + 16 = 30
      expect(encrypted.length, 30);
    });
  });

  // ==========================================================================
  // Transcript
  // ==========================================================================
  group('CryptoPrimitives.buildTranscript', () {
    test('transcript is exactly 140 bytes', () {
      final transcript = CryptoPrimitives.buildTranscript(
        pkEphP: Uint8List(32),
        pkEphL: Uint8List(32),
        challengeP: Uint8List(32),
        challengeL: Uint8List(32),
      );

      expect(transcript.length, 140);
    });

    test('transcript starts with domain prefix and version', () {
      final transcript = CryptoPrimitives.buildTranscript(
        pkEphP: Uint8List(32),
        pkEphL: Uint8List(32),
        challengeP: Uint8List(32),
        challengeL: Uint8List(32),
      );

      // "SLOCK-HS-v1" = 11 bytes
      final prefix = utf8.encode(ProtocolConstants.transcriptPrefix);
      expect(transcript.sublist(0, prefix.length), orderedEquals(prefix));
      expect(transcript[prefix.length], ProtocolConstants.versionByte);
    });

    test('transcript fields are concatenated in correct order', () {
      final pkEphP = Uint8List(32)..fillRange(0, 32, 0x11);
      final pkEphL = Uint8List(32)..fillRange(0, 32, 0x22);
      final challengeP = Uint8List(32)..fillRange(0, 32, 0x33);
      final challengeL = Uint8List(32)..fillRange(0, 32, 0x44);

      final transcript = CryptoPrimitives.buildTranscript(
        pkEphP: pkEphP,
        pkEphL: pkEphL,
        challengeP: challengeP,
        challengeL: challengeL,
      );

      // After prefix (11) + version (1) = offset 12
      expect(transcript.sublist(12, 44), orderedEquals(pkEphP));
      expect(transcript.sublist(44, 76), orderedEquals(pkEphL));
      expect(transcript.sublist(76, 108), orderedEquals(challengeP));
      expect(transcript.sublist(108, 140), orderedEquals(challengeL));
    });

    test('transcript is deterministic', () {
      final pkEphP = Uint8List(32)..fillRange(0, 32, 0xAA);
      final pkEphL = Uint8List(32)..fillRange(0, 32, 0xBB);
      final challengeP = Uint8List(32)..fillRange(0, 32, 0xCC);
      final challengeL = Uint8List(32)..fillRange(0, 32, 0xDD);

      final t1 = CryptoPrimitives.buildTranscript(
        pkEphP: pkEphP,
        pkEphL: pkEphL,
        challengeP: challengeP,
        challengeL: challengeL,
      );
      final t2 = CryptoPrimitives.buildTranscript(
        pkEphP: pkEphP,
        pkEphL: pkEphL,
        challengeP: challengeP,
        challengeL: challengeL,
      );

      expect(t1, orderedEquals(t2));
    });
  });

  // ==========================================================================
  // Secure Random
  // ==========================================================================
  group('CryptoPrimitives.generateSecureRandom', () {
    test('returns requested length', () {
      expect(CryptoPrimitives.generateSecureRandom(0).length, 0);
      expect(CryptoPrimitives.generateSecureRandom(1).length, 1);
      expect(CryptoPrimitives.generateSecureRandom(32).length, 32);
      expect(CryptoPrimitives.generateSecureRandom(64).length, 64);
    });

    test('two calls produce different bytes', () {
      final a = CryptoPrimitives.generateSecureRandom(32);
      final b = CryptoPrimitives.generateSecureRandom(32);
      // Probability of collision is 2^-256 — safe to assert
      expect(a, isNot(orderedEquals(b)));
    });
  });

  // ==========================================================================
  // End-to-end: Full handshake simulation
  // ==========================================================================
  group('End-to-end handshake simulation', () {
    test('phone and lock derive identical session keys', () async {
      // --- Phone side ---
      final phoneEph =
          await CryptoPrimitives.generateX25519KeyPair();
      final challengeP = CryptoPrimitives.generateSecureRandom(32);

      // --- Lock side ---
      final lockEph =
          await CryptoPrimitives.generateX25519KeyPair();
      final challengeL = CryptoPrimitives.generateSecureRandom(32);

      // --- Both sides compute shared secret ---
      final ssPhone = await CryptoPrimitives.x25519SharedSecret(
        localPrivateKey: phoneEph.privateKey,
        remotePublicKey: lockEph.publicKey,
      );
      final ssLock = await CryptoPrimitives.x25519SharedSecret(
        localPrivateKey: lockEph.privateKey,
        remotePublicKey: phoneEph.publicKey,
      );

      expect(ssPhone, orderedEquals(ssLock));

      // --- Both sides derive session keys ---
      final phoneKeys = await CryptoPrimitives.deriveSessionKeys(
        sharedSecret: ssPhone,
        challengeP: challengeP,
        challengeL: challengeL,
      );
      final lockKeys = await CryptoPrimitives.deriveSessionKeys(
        sharedSecret: ssLock,
        challengeP: challengeP,
        challengeL: challengeL,
      );

      // Phone's K_p2e == Lock's K_p2e, and so on
      expect(phoneKeys.phoneToEsp, orderedEquals(lockKeys.phoneToEsp));
      expect(phoneKeys.espToPhone, orderedEquals(lockKeys.espToPhone));
    });

    test('phone encrypts with K_p2e, lock decrypts with K_p2e', () async {
      final phoneEph = await CryptoPrimitives.generateX25519KeyPair();
      final lockEph = await CryptoPrimitives.generateX25519KeyPair();
      final cP = CryptoPrimitives.generateSecureRandom(32);
      final cL = CryptoPrimitives.generateSecureRandom(32);

      final ss = await CryptoPrimitives.x25519SharedSecret(
        localPrivateKey: phoneEph.privateKey,
        remotePublicKey: lockEph.publicKey,
      );

      final keys = await CryptoPrimitives.deriveSessionKeys(
        sharedSecret: ss,
        challengeP: cP,
        challengeL: cL,
      );

      // Phone sends an encrypted command
      final command = Uint8List.fromList([0x02]); // CMD_UNLOCK
      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: keys.phoneToEsp,
        plaintext: command,
      );

      // Lock decrypts with the same K_p2e
      final decrypted = await CryptoPrimitives.aesGcmDecrypt(
        key: keys.phoneToEsp,
        encryptedPayload: encrypted,
      );

      expect(decrypted, orderedEquals(command));
    });

    test('lock encrypts with K_e2p, phone decrypts with K_e2p', () async {
      final phoneEph = await CryptoPrimitives.generateX25519KeyPair();
      final lockEph = await CryptoPrimitives.generateX25519KeyPair();
      final cP = CryptoPrimitives.generateSecureRandom(32);
      final cL = CryptoPrimitives.generateSecureRandom(32);

      final ss = await CryptoPrimitives.x25519SharedSecret(
        localPrivateKey: phoneEph.privateKey,
        remotePublicKey: lockEph.publicKey,
      );

      final keys = await CryptoPrimitives.deriveSessionKeys(
        sharedSecret: ss,
        challengeP: cP,
        challengeL: cL,
      );

      // Lock sends an encrypted response
      final response = Uint8List.fromList([0x00]); // APP_STATUS_OK
      final encrypted = await CryptoPrimitives.aesGcmEncrypt(
        key: keys.espToPhone,
        plaintext: response,
      );

      // Phone decrypts with K_e2p
      final decrypted = await CryptoPrimitives.aesGcmDecrypt(
        key: keys.espToPhone,
        encryptedPayload: encrypted,
      );

      expect(decrypted, orderedEquals(response));
    });

    test('transcript-based Ed25519 signatures verify cross-party', () async {
      // Generate long-term Ed25519 identities
      final phoneLt = await CryptoPrimitives.generateEd25519KeyPair();
      final lockLt = await CryptoPrimitives.generateEd25519KeyPair();

      // Generate ephemeral X25519 keys
      final phoneEph = await CryptoPrimitives.generateX25519KeyPair();
      final lockEph = await CryptoPrimitives.generateX25519KeyPair();
      final cP = CryptoPrimitives.generateSecureRandom(32);
      final cL = CryptoPrimitives.generateSecureRandom(32);

      // Build transcript (both sides build the same one)
      final transcript = CryptoPrimitives.buildTranscript(
        pkEphP: phoneEph.publicKey,
        pkEphL: lockEph.publicKey,
        challengeP: cP,
        challengeL: cL,
      );

      // Lock signs transcript → Sig_L (M2)
      final sigL = await CryptoPrimitives.ed25519Sign(
        message: transcript,
        privateKey: lockLt.privateKey,
        publicKey: lockLt.publicKey,
      );

      // Phone verifies Sig_L with Lock's public key
      final sigLValid = await CryptoPrimitives.ed25519Verify(
        message: transcript,
        signatureBytes: sigL,
        publicKey: lockLt.publicKey,
      );
      expect(sigLValid, isTrue);

      // Phone signs transcript → Sig_P (M3)
      final sigP = await CryptoPrimitives.ed25519Sign(
        message: transcript,
        privateKey: phoneLt.privateKey,
        publicKey: phoneLt.publicKey,
      );

      // Lock verifies Sig_P with Phone's public key
      final sigPValid = await CryptoPrimitives.ed25519Verify(
        message: transcript,
        signatureBytes: sigP,
        publicKey: phoneLt.publicKey,
      );
      expect(sigPValid, isTrue);

      // Cross-check: Sig_L should NOT verify against Phone's key
      final crossFail = await CryptoPrimitives.ed25519Verify(
        message: transcript,
        signatureBytes: sigL,
        publicKey: phoneLt.publicKey,
      );
      expect(crossFail, isFalse);
    });
  });
}
