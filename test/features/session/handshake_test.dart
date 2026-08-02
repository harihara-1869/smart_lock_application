import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';
import 'package:smartlock_application/features/session/crypto/crypto_primitives.dart';
import 'package:smartlock_application/features/session/handshake.dart';

/// Unwrap a [Result], failing the test with [message] on [Err].
T _unwrap<T, E>(Result<T, E> result, String message) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final error) => fail('$message: $error'),
  };
}

/// Helper: build a synthetic but valid M2 payload (128 bytes) given the phone's
/// ephemeral context and the lock's long-term keypair.
///
/// Mirrors what the lock firmware does on receiving M1: generate a lock
/// ephemeral X25519 keypair + challenge, build the transcript, sign it with the
/// lock Ed25519 key, and return `pk_eph_L ‖ c_L ‖ Sig_L`.
Future<({Uint8List m2Data, Uint8List pkEphL, Uint8List challengeL})>
    _buildValidM2({
  required Uint8List phoneEphPublicKey,
  required Uint8List phoneChallengeP,
  required Uint8List lockSeed,
  required Uint8List lockPublicKey,
}) async {
  final lockEph = await CryptoPrimitives.generateX25519KeyPair();
  final challengeL = CryptoPrimitives.generateSecureRandom(32);

  final transcript = CryptoPrimitives.buildTranscript(
    pkEphP: phoneEphPublicKey,
    pkEphL: lockEph.publicKey,
    challengeP: phoneChallengeP,
    challengeL: challengeL,
  );

  final sigL = await CryptoPrimitives.ed25519Sign(
    message: transcript,
    privateKey: lockSeed,
    publicKey: lockPublicKey,
  );

  final m2Data = Uint8List(ProtocolConstants.m2Length)
    ..setRange(0, 32, lockEph.publicKey)
    ..setRange(32, 64, challengeL)
    ..setRange(64, 128, sigL);

  return (
    m2Data: m2Data,
    pkEphL: lockEph.publicKey,
    challengeL: challengeL,
  );
}

void main() {
  // ==========================================================================
  // buildM1
  // ==========================================================================
  group('Handshake.buildM1', () {
    test('returns 64-byte payload', () async {
      final (payload, ctx) = await Handshake.buildM1();

      expect(payload.length, ProtocolConstants.m1Length);
      expect(ctx.ephPrivateKey.length, ProtocolConstants.x25519KeyLength);
      expect(ctx.ephPublicKey.length, ProtocolConstants.x25519KeyLength);
      expect(ctx.challengeP.length, ProtocolConstants.challengeLength);
    });

    test('payload is pk_eph_P ‖ c_P', () async {
      final (payload, ctx) = await Handshake.buildM1();

      expect(payload.sublist(0, 32), orderedEquals(ctx.ephPublicKey));
      expect(payload.sublist(32, 64), orderedEquals(ctx.challengeP));
    });
  });

  // ==========================================================================
  // parseAndVerifyM2
  // ==========================================================================
  group('Handshake.parseAndVerifyM2', () {
    test('succeeds with valid signature', () async {
      final lockLt = await CryptoPrimitives.generateEd25519KeyPair();
      final (_, ctx) = await Handshake.buildM1();

      final built = await _buildValidM2(
        phoneEphPublicKey: ctx.ephPublicKey,
        phoneChallengeP: ctx.challengeP,
        lockSeed: lockLt.privateKey,
        lockPublicKey: lockLt.publicKey,
      );

      final result = await Handshake.parseAndVerifyM2(
        m2Data: built.m2Data,
        ctx: ctx,
        lockPublicKey: lockLt.publicKey,
      );

      final m2 = _unwrap(result, 'M2 verification should succeed');
      expect(m2.pkEphL, orderedEquals(built.pkEphL));
      expect(m2.challengeL, orderedEquals(built.challengeL));
      expect(m2.sigL.length, ProtocolConstants.ed25519SigLength);
      expect(m2.transcript.length, 140);
      expect(m2.sharedSecret.length, ProtocolConstants.x25519KeyLength);
    });

    test('rejects invalid M2 length', () async {
      final lockLt = await CryptoPrimitives.generateEd25519KeyPair();
      final (_, ctx) = await Handshake.buildM1();

      final result = await Handshake.parseAndVerifyM2(
        m2Data: Uint8List(100),
        ctx: ctx,
        lockPublicKey: lockLt.publicKey,
      );

      expect(result, isA<Err<M2Result, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcUnexpected>());
        case Ok(:final value):
          fail('Expected Err, got Ok: $value');
      }
    });

    test('rejects bad signature', () async {
      final lockLt = await CryptoPrimitives.generateEd25519KeyPair();
      final (_, ctx) = await Handshake.buildM1();

      final built = await _buildValidM2(
        phoneEphPublicKey: ctx.ephPublicKey,
        phoneChallengeP: ctx.challengeP,
        lockSeed: lockLt.privateKey,
        lockPublicKey: lockLt.publicKey,
      );

      // Flip a bit in Sig_L (bytes 64:128).
      built.m2Data[70] ^= 0xFF;

      final result = await Handshake.parseAndVerifyM2(
        m2Data: built.m2Data,
        ctx: ctx,
        lockPublicKey: lockLt.publicKey,
      );

      expect(result, isA<Err<M2Result, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcAuthenticationFailed>());
        case Ok(:final value):
          fail('Expected Err, got Ok: $value');
      }
    });

    test('rejects wrong lock key', () async {
      final lockA = await CryptoPrimitives.generateEd25519KeyPair();
      final lockB = await CryptoPrimitives.generateEd25519KeyPair();
      final (_, ctx) = await Handshake.buildM1();

      // M2 signed by lock A...
      final built = await _buildValidM2(
        phoneEphPublicKey: ctx.ephPublicKey,
        phoneChallengeP: ctx.challengeP,
        lockSeed: lockA.privateKey,
        lockPublicKey: lockA.publicKey,
      );

      // ...but verified against lock B's key.
      final result = await Handshake.parseAndVerifyM2(
        m2Data: built.m2Data,
        ctx: ctx,
        lockPublicKey: lockB.publicKey,
      );

      expect(result, isA<Err<M2Result, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcAuthenticationFailed>());
        case Ok(:final value):
          fail('Expected Err, got Ok: $value');
      }
    });
  });

  // ==========================================================================
  // cacheM2ForProvisioning
  // ==========================================================================
  group('Handshake.cacheM2ForProvisioning', () {
    test('caches without verifying', () async {
      final lockLt = await CryptoPrimitives.generateEd25519KeyPair();
      final (_, ctx) = await Handshake.buildM1();

      final built = await _buildValidM2(
        phoneEphPublicKey: ctx.ephPublicKey,
        phoneChallengeP: ctx.challengeP,
        lockSeed: lockLt.privateKey,
        lockPublicKey: lockLt.publicKey,
      );

      // No lock public key is supplied — caching must still succeed.
      final result = await Handshake.cacheM2ForProvisioning(
        m2Data: built.m2Data,
        ctx: ctx,
      );

      final cached = _unwrap(result, 'cache should succeed');
      expect(cached.pkEphL, orderedEquals(built.pkEphL));
      expect(cached.challengeL, orderedEquals(built.challengeL));
      // Sig_L is cached even though it was not verified.
      expect(cached.sigL, orderedEquals(built.m2Data.sublist(64, 128)));
      expect(cached.transcript.length, 140);
      expect(cached.sharedSecret.length, 32);
    });
  });

  // ==========================================================================
  // buildM3
  // ==========================================================================
  group('Handshake.buildM3', () {
    test('returns 64-byte signature payload', () async {
      final phoneLt = await CryptoPrimitives.generateEd25519KeyPair();
      final transcript = CryptoPrimitives.buildTranscript(
        pkEphP: Uint8List(32),
        pkEphL: Uint8List(32),
        challengeP: Uint8List(32),
        challengeL: Uint8List(32),
      );

      final result = await Handshake.buildM3(
        transcript: transcript,
        phoneSeed: phoneLt.privateKey,
        phonePublicKey: phoneLt.publicKey,
        sharedSecret: CryptoPrimitives.generateSecureRandom(32),
        challengeP: CryptoPrimitives.generateSecureRandom(32),
        challengeL: CryptoPrimitives.generateSecureRandom(32),
      );

      expect(result.m3Payload.length, ProtocolConstants.ed25519SigLength);
    });

    test('produces valid Sig_P verifiable by lock', () async {
      final phoneLt = await CryptoPrimitives.generateEd25519KeyPair();

      final transcript = CryptoPrimitives.buildTranscript(
        pkEphP: Uint8List(32)..fillRange(0, 32, 0x01),
        pkEphL: Uint8List(32)..fillRange(0, 32, 0x02),
        challengeP: Uint8List(32)..fillRange(0, 32, 0x03),
        challengeL: Uint8List(32)..fillRange(0, 32, 0x04),
      );

      final result = await Handshake.buildM3(
        transcript: transcript,
        phoneSeed: phoneLt.privateKey,
        phonePublicKey: phoneLt.publicKey,
        sharedSecret: CryptoPrimitives.generateSecureRandom(32),
        challengeP: CryptoPrimitives.generateSecureRandom(32),
        challengeL: CryptoPrimitives.generateSecureRandom(32),
      );

      // The lock would verify Sig_P against the phone's public key.
      final valid = await CryptoPrimitives.ed25519Verify(
        message: transcript,
        signatureBytes: result.m3Payload,
        publicKey: phoneLt.publicKey,
      );

      expect(valid, isTrue);
    });

    test('derives two distinct 32-byte session keys', () async {
      final phoneLt = await CryptoPrimitives.generateEd25519KeyPair();
      final transcript = Uint8List(140);

      final result = await Handshake.buildM3(
        transcript: transcript,
        phoneSeed: phoneLt.privateKey,
        phonePublicKey: phoneLt.publicKey,
        sharedSecret: Uint8List(32)..fillRange(0, 32, 0xAA),
        challengeP: Uint8List(32)..fillRange(0, 32, 0xBB),
        challengeL: Uint8List(32)..fillRange(0, 32, 0xCC),
      );

      expect(result.kP2E.length, ProtocolConstants.derivedKeyLength);
      expect(result.kE2P.length, ProtocolConstants.derivedKeyLength);
      expect(result.kP2E, isNot(orderedEquals(result.kE2P)));
    });
  });

  // ==========================================================================
  // verifyDeferredM2
  // ==========================================================================
  group('Handshake.verifyDeferredM2', () {
    test('succeeds with correct lock key', () async {
      final lockLt = await CryptoPrimitives.generateEd25519KeyPair();
      final (_, ctx) = await Handshake.buildM1();

      final built = await _buildValidM2(
        phoneEphPublicKey: ctx.ephPublicKey,
        phoneChallengeP: ctx.challengeP,
        lockSeed: lockLt.privateKey,
        lockPublicKey: lockLt.publicKey,
      );

      final cached = _unwrap(
        await Handshake.cacheM2ForProvisioning(
          m2Data: built.m2Data,
          ctx: ctx,
        ),
        'cache should succeed',
      );

      final valid = await Handshake.verifyDeferredM2(
        cached: cached,
        lockPublicKey: lockLt.publicKey,
      );

      expect(valid, isTrue);
    });

    test('fails with wrong lock key', () async {
      final lockA = await CryptoPrimitives.generateEd25519KeyPair();
      final lockB = await CryptoPrimitives.generateEd25519KeyPair();
      final (_, ctx) = await Handshake.buildM1();

      final built = await _buildValidM2(
        phoneEphPublicKey: ctx.ephPublicKey,
        phoneChallengeP: ctx.challengeP,
        lockSeed: lockA.privateKey,
        lockPublicKey: lockA.publicKey,
      );

      final cached = _unwrap(
        await Handshake.cacheM2ForProvisioning(
          m2Data: built.m2Data,
          ctx: ctx,
        ),
        'cache should succeed',
      );

      final valid = await Handshake.verifyDeferredM2(
        cached: cached,
        lockPublicKey: lockB.publicKey,
      );

      expect(valid, isFalse);
    });
  });

  // ==========================================================================
  // End-to-end: full M1 → M2 → M3
  // ==========================================================================
  group('Handshake end-to-end', () {
    test('full M1→M2→M3 derives identical session keys on both sides',
        () async {
      // --- Long-term identities ---
      final phoneLt = await CryptoPrimitives.generateEd25519KeyPair();
      final lockLt = await CryptoPrimitives.generateEd25519KeyPair();

      // --- Phone: M1 ---
      final (m1Payload, ctx) = await Handshake.buildM1();
      expect(m1Payload.length, ProtocolConstants.m1Length);

      // --- Lock: receive M1, build M2 ---
      final lockEph = await CryptoPrimitives.generateX25519KeyPair();
      final challengeL = CryptoPrimitives.generateSecureRandom(32);

      final transcript = CryptoPrimitives.buildTranscript(
        pkEphP: ctx.ephPublicKey,
        pkEphL: lockEph.publicKey,
        challengeP: ctx.challengeP,
        challengeL: challengeL,
      );

      final sigL = await CryptoPrimitives.ed25519Sign(
        message: transcript,
        privateKey: lockLt.privateKey,
        publicKey: lockLt.publicKey,
      );

      final m2Data = Uint8List(ProtocolConstants.m2Length)
        ..setRange(0, 32, lockEph.publicKey)
        ..setRange(32, 64, challengeL)
        ..setRange(64, 128, sigL);

      // --- Phone: parse & verify M2 ---
      final m2 = _unwrap(
        await Handshake.parseAndVerifyM2(
          m2Data: m2Data,
          ctx: ctx,
          lockPublicKey: lockLt.publicKey,
        ),
        'M2 verification should succeed',
      );

      // --- Phone: build M3 + derive session keys ---
      final phoneResult = await Handshake.buildM3(
        transcript: m2.transcript,
        phoneSeed: phoneLt.privateKey,
        phonePublicKey: phoneLt.publicKey,
        sharedSecret: m2.sharedSecret,
        challengeP: ctx.challengeP,
        challengeL: m2.challengeL,
      );

      // --- Lock: independently derive the same session keys ---
      final lockSharedSecret = await CryptoPrimitives.x25519SharedSecret(
        localPrivateKey: lockEph.privateKey,
        remotePublicKey: ctx.ephPublicKey,
      );

      final lockKeys = await CryptoPrimitives.deriveSessionKeys(
        sharedSecret: lockSharedSecret,
        challengeP: ctx.challengeP,
        challengeL: challengeL,
      );

      // Both sides arrive at identical directional keys.
      expect(phoneResult.kP2E, orderedEquals(lockKeys.phoneToEsp));
      expect(phoneResult.kE2P, orderedEquals(lockKeys.espToPhone));

      // And Sig_P is verifiable by the lock against the phone's public key.
      final sigPValid = await CryptoPrimitives.ed25519Verify(
        message: m2.transcript,
        signatureBytes: phoneResult.m3Payload,
        publicKey: phoneLt.publicKey,
      );
      expect(sigPValid, isTrue);
    });
  });
}
