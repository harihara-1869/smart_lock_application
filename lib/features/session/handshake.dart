import 'dart:typed_data';

import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';
import 'package:smartlock_application/features/session/crypto/crypto_primitives.dart';

/// Ephemeral state generated for M1 and needed through M3.
///
/// Held by the caller (SessionController) across the M1→M2→M3 exchange: the
/// ephemeral private key is required to compute the shared secret at M2, and
/// the phone's ephemeral public key + challenge are required to build the
/// transcript that M3 signs.
class HandshakeContext {
  /// 32 bytes — X25519 ephemeral private key.
  final Uint8List ephPrivateKey;

  /// 32 bytes — X25519 ephemeral public key (sent in M1).
  final Uint8List ephPublicKey;

  /// 32 bytes — phone's challenge (sent in M1).
  final Uint8List challengeP;

  HandshakeContext({
    required this.ephPrivateKey,
    required this.ephPublicKey,
    required this.challengeP,
  });
}

/// Parsed M2 result for normal (authenticated) sessions.
///
/// `Sig_L` has already been verified against [lockPublicKey] by the time this
/// is returned.
class M2Result {
  /// 32 bytes — lock's ephemeral X25519 public key.
  final Uint8List pkEphL;

  /// 32 bytes — lock's challenge.
  final Uint8List challengeL;

  /// 64 bytes — lock's Ed25519 signature.
  final Uint8List sigL;

  /// 140 bytes — full domain-separated transcript.
  final Uint8List transcript;

  /// 32 bytes — X25519(sk_eph_P, pk_eph_L).
  final Uint8List sharedSecret;

  M2Result({
    required this.pkEphL,
    required this.challengeL,
    required this.sigL,
    required this.transcript,
    required this.sharedSecret,
  });
}

/// Cached M2 for provisioning (Sig_L NOT verified yet).
///
/// Used during provisioning when the phone does not yet know the lock's public
/// key: [sigL] and [transcript] are cached so [Handshake.verifyDeferredM2] can
/// validate them against the lock key returned in the CMD_PROVISION response.
class DeferredM2 {
  /// 32 bytes — lock's ephemeral X25519 public key.
  final Uint8List pkEphL;

  /// 32 bytes — lock's challenge.
  final Uint8List challengeL;

  /// 64 bytes — cached, unverified lock signature.
  final Uint8List sigL;

  /// 140 bytes — cached transcript for later verification.
  final Uint8List transcript;

  /// 32 bytes — X25519(sk_eph_P, pk_eph_L).
  final Uint8List sharedSecret;

  DeferredM2({
    required this.pkEphL,
    required this.challengeL,
    required this.sigL,
    required this.transcript,
    required this.sharedSecret,
  });
}

/// Pure functions for building/parsing the SLOCK-HS-v1 handshake messages and
/// deriving session keys.
///
/// No I/O, no state — every method is static. The caller owns the
/// [HandshakeContext] between M1 and M3.
abstract final class Handshake {
  /// Step 1: Generate the M1 payload and the ephemeral context needed for the
  /// rest of the exchange.
  ///
  /// Returns the M1 payload (64 bytes: `pk_eph_P ‖ c_P`) and a
  /// [HandshakeContext] that must be threaded into M2/M3.
  static Future<(Uint8List m1Payload, HandshakeContext ctx)> buildM1() async {
    // 1. Ephemeral X25519 keypair for this session.
    final ephKp = await CryptoPrimitives.generateX25519KeyPair();

    // 2. Phone's 32-byte challenge.
    final challengeP = CryptoPrimitives.generateSecureRandom(
      ProtocolConstants.challengeLength,
    );

    // 3. M1 payload: pk_eph_P(32) ‖ c_P(32) = 64 bytes.
    final m1Payload = Uint8List(ProtocolConstants.m1Length)
      ..setRange(0, 32, ephKp.publicKey)
      ..setRange(32, 64, challengeP);

    // 4. Context carried through M3.
    final ctx = HandshakeContext(
      ephPrivateKey: ephKp.privateKey,
      ephPublicKey: ephKp.publicKey,
      challengeP: challengeP,
    );

    return (m1Payload, ctx);
  }

  /// Step 2a (normal session): Parse M2, verify `Sig_L`, compute the shared
  /// secret.
  ///
  /// - [m2Data]: the 128-byte R-APDU data from the M2 response.
  /// - [ctx]: the [HandshakeContext] from [buildM1].
  /// - [lockPublicKey]: the lock's Ed25519 public key (from TrustedLocksStore).
  ///
  /// Returns [M2Result] on success, [NfcSessionError] on failure.
  static Future<Result<M2Result, NfcSessionError>> parseAndVerifyM2({
    required Uint8List m2Data,
    required HandshakeContext ctx,
    required Uint8List lockPublicKey,
  }) async {
    // 1. Length check.
    if (m2Data.length != ProtocolConstants.m2Length) {
      return Result.err(
        NfcSessionError.unexpected(
          'M2 data length mismatch: ${m2Data.length}',
        ),
      );
    }

    // 2. Parse: pkEphL(0:32) ‖ c_L(32:64) ‖ Sig_L(64:128).
    final pkEphL = Uint8List.sublistView(m2Data, 0, 32);
    final challengeL = Uint8List.sublistView(m2Data, 32, 64);
    final sigL = Uint8List.sublistView(m2Data, 64, 128);

    // 3. Domain-separated transcript.
    final transcript = CryptoPrimitives.buildTranscript(
      pkEphP: ctx.ephPublicKey,
      pkEphL: pkEphL,
      challengeP: ctx.challengeP,
      challengeL: challengeL,
    );

    // 4. Verify Sig_L with the lock's long-term public key.
    final sigValid = await CryptoPrimitives.ed25519Verify(
      message: transcript,
      signatureBytes: sigL,
      publicKey: lockPublicKey,
    );
    if (!sigValid) {
      return const Result.err(NfcSessionError.authenticationFailed());
    }

    // 5. Shared secret: X25519(sk_eph_P, pk_eph_L).
    final sharedSecret = await CryptoPrimitives.x25519SharedSecret(
      localPrivateKey: ctx.ephPrivateKey,
      remotePublicKey: pkEphL,
    );

    return Result.ok(
      M2Result(
        pkEphL: Uint8List.fromList(pkEphL),
        challengeL: Uint8List.fromList(challengeL),
        sigL: Uint8List.fromList(sigL),
        transcript: transcript,
        sharedSecret: sharedSecret,
      ),
    );
  }

  /// Step 2b (provisioning): Parse M2 WITHOUT verifying `Sig_L`.
  ///
  /// Caches `Sig_L` and the transcript for deferred verification after
  /// CMD_PROVISION. Used when the phone doesn't know the lock's public key
  /// yet.
  static Future<Result<DeferredM2, NfcSessionError>> cacheM2ForProvisioning({
    required Uint8List m2Data,
    required HandshakeContext ctx,
  }) async {
    // 1. Length check.
    if (m2Data.length != ProtocolConstants.m2Length) {
      return Result.err(
        NfcSessionError.unexpected(
          'M2 data length mismatch: ${m2Data.length}',
        ),
      );
    }

    // 2. Parse: pkEphL(0:32) ‖ c_L(32:64) ‖ Sig_L(64:128).
    final pkEphL = Uint8List.sublistView(m2Data, 0, 32);
    final challengeL = Uint8List.sublistView(m2Data, 32, 64);
    final sigL = Uint8List.sublistView(m2Data, 64, 128);

    // 3. Transcript (cached for deferred verification).
    final transcript = CryptoPrimitives.buildTranscript(
      pkEphP: ctx.ephPublicKey,
      pkEphL: pkEphL,
      challengeP: ctx.challengeP,
      challengeL: challengeL,
    );

    // 4. Shared secret (still computed — needed for the secure channel).
    final sharedSecret = await CryptoPrimitives.x25519SharedSecret(
      localPrivateKey: ctx.ephPrivateKey,
      remotePublicKey: pkEphL,
    );

    // NOTE: Sig_L verification is intentionally skipped here.
    return Result.ok(
      DeferredM2(
        pkEphL: Uint8List.fromList(pkEphL),
        challengeL: Uint8List.fromList(challengeL),
        sigL: Uint8List.fromList(sigL),
        transcript: transcript,
        sharedSecret: sharedSecret,
      ),
    );
  }

  /// Step 3: Build the M3 payload (`Sig_P`) and derive the session keys.
  ///
  /// - [transcript]: from [M2Result] or [DeferredM2].
  /// - [phoneSeed]: phone's Ed25519 32-byte seed (from IdentityKeystore).
  /// - [phonePublicKey]: phone's Ed25519 32-byte public key.
  /// - [sharedSecret]: from [M2Result] or [DeferredM2].
  /// - [challengeP]: from [HandshakeContext].
  /// - [challengeL]: from [M2Result] or [DeferredM2].
  ///
  /// Returns `(m3Payload: 64 bytes, kP2E: 32 bytes, kE2P: 32 bytes)`.
  static Future<({Uint8List m3Payload, Uint8List kP2E, Uint8List kE2P})>
      buildM3({
    required Uint8List transcript,
    required Uint8List phoneSeed,
    required Uint8List phonePublicKey,
    required Uint8List sharedSecret,
    required Uint8List challengeP,
    required Uint8List challengeL,
  }) async {
    // 1. Sig_P over the transcript — this IS the M3 payload (64 bytes).
    final m3Payload = await CryptoPrimitives.ed25519Sign(
      message: transcript,
      privateKey: phoneSeed,
      publicKey: phonePublicKey,
    );

    // 2. Derive directional session keys.
    final keys = await CryptoPrimitives.deriveSessionKeys(
      sharedSecret: sharedSecret,
      challengeP: challengeP,
      challengeL: challengeL,
    );

    return (
      m3Payload: m3Payload,
      kP2E: keys.phoneToEsp,
      kE2P: keys.espToPhone,
    );
  }

  /// Deferred verification: check the cached `Sig_L` against a lock public key
  /// received in the CMD_PROVISION response.
  ///
  /// Returns `true` if `Sig_L` is valid for the given public key and
  /// transcript.
  static Future<bool> verifyDeferredM2({
    required DeferredM2 cached,
    required Uint8List lockPublicKey,
  }) async {
    return CryptoPrimitives.ed25519Verify(
      message: cached.transcript,
      signatureBytes: cached.sigL,
      publicKey: lockPublicKey,
    );
  }
}
