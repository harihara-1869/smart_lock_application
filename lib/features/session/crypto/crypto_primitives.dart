import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:smartlock_application/features/nfc/protocol_constants.dart';

/// Pure cryptographic primitives used by the session handshake and secure
/// channel. Every method is static and side-effect-free — no state, no I/O.
///
/// Wraps the `cryptography` package (v2.9.0) and exposes only the exact
/// operations the SLOCK-HS-v1 protocol needs, with raw `Uint8List` inputs
/// and outputs so callers never touch library-specific key types directly.
abstract final class CryptoPrimitives {
  // -------------------------------------------------------------------------
  // Algorithm singletons (reused across calls)
  // -------------------------------------------------------------------------

  static final _x25519 = X25519();
  static final _ed25519 = Ed25519();
  static final _aesGcm = AesGcm.with256bits();
  static final _hmacSha256 = Hmac.sha256();

  // -------------------------------------------------------------------------
  // X25519 — Ephemeral key exchange
  // -------------------------------------------------------------------------

  /// Generate a fresh X25519 keypair.
  ///
  /// Returns `(privateKey: 32 bytes, publicKey: 32 bytes)`.
  static Future<({Uint8List privateKey, Uint8List publicKey})>
      generateX25519KeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final extracted = await keyPair.extract();
    final privateKey = Uint8List.fromList(extracted.bytes);
    final publicKey = Uint8List.fromList(extracted.publicKey.bytes);
    return (privateKey: privateKey, publicKey: publicKey);
  }

  /// Construct an X25519 keypair from an existing seed/private key (32 bytes).
  ///
  /// Returns `(privateKey: 32 bytes, publicKey: 32 bytes)`.
  static Future<({Uint8List privateKey, Uint8List publicKey})>
      x25519KeyPairFromSeed(Uint8List seed) async {
    assert(seed.length == 32, 'X25519 seed must be 32 bytes');
    final keyPair = await _x25519.newKeyPairFromSeed(seed);
    final extracted = await keyPair.extract();
    final privateKey = Uint8List.fromList(extracted.bytes);
    final publicKey = Uint8List.fromList(extracted.publicKey.bytes);
    return (privateKey: privateKey, publicKey: publicKey);
  }

  /// Compute the X25519 shared secret.
  ///
  /// - [localPrivateKey]: our ephemeral X25519 private key (32 bytes).
  /// - [remotePublicKey]: peer's ephemeral X25519 public key (32 bytes).
  ///
  /// Returns the raw 32-byte shared secret.
  static Future<Uint8List> x25519SharedSecret({
    required Uint8List localPrivateKey,
    required Uint8List remotePublicKey,
  }) async {
    assert(localPrivateKey.length == 32, 'X25519 private key must be 32 bytes');
    assert(remotePublicKey.length == 32, 'X25519 public key must be 32 bytes');

    // Reconstruct the keypair from our private key bytes.
    final keyPair = await _x25519.newKeyPairFromSeed(localPrivateKey);
    final remotePk = SimplePublicKey(
      List<int>.from(remotePublicKey),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePk,
    );

    return Uint8List.fromList(await sharedSecret.extractBytes());
  }

  // -------------------------------------------------------------------------
  // Ed25519 — Digital signatures
  // -------------------------------------------------------------------------

  /// Generate a fresh Ed25519 keypair.
  ///
  /// Returns `(privateKey: 32-byte seed, publicKey: 32 bytes)`.
  /// The firmware uses a 64-byte layout (`seed 32B ‖ public 32B`); that
  /// composition is done at the IdentityKeystore layer, not here.
  static Future<({Uint8List privateKey, Uint8List publicKey})>
      generateEd25519KeyPair() async {
    final keyPair = await _ed25519.newKeyPair();
    final extracted = await keyPair.extract();
    final privateKey = Uint8List.fromList(extracted.bytes);
    final publicKey = Uint8List.fromList(extracted.publicKey.bytes);
    return (privateKey: privateKey, publicKey: publicKey);
  }

  /// Construct an Ed25519 keypair from a 32-byte seed.
  ///
  /// Returns `(privateKey: 32-byte seed, publicKey: 32 bytes)`.
  static Future<({Uint8List privateKey, Uint8List publicKey})>
      ed25519KeyPairFromSeed(Uint8List seed) async {
    assert(seed.length == 32, 'Ed25519 seed must be 32 bytes');
    final keyPair = await _ed25519.newKeyPairFromSeed(seed);
    final extracted = await keyPair.extract();
    final privateKey = Uint8List.fromList(extracted.bytes);
    final publicKey = Uint8List.fromList(extracted.publicKey.bytes);
    return (privateKey: privateKey, publicKey: publicKey);
  }

  /// Sign [message] with an Ed25519 private key.
  ///
  /// - [privateKey]: 32-byte Ed25519 seed (the `cryptography` package format).
  /// - [publicKey]: 32-byte Ed25519 public key.
  ///
  /// Returns 64-byte signature.
  static Future<Uint8List> ed25519Sign({
    required Uint8List message,
    required Uint8List privateKey,
    required Uint8List publicKey,
  }) async {
    final keyPair = SimpleKeyPairData(
      List<int>.from(privateKey),
      publicKey: SimplePublicKey(
        List<int>.from(publicKey),
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );

    final signature = await _ed25519.sign(
      message,
      keyPair: keyPair,
    );

    return Uint8List.fromList(signature.bytes);
  }

  /// Verify an Ed25519 signature.
  ///
  /// - [message]: the data that was signed.
  /// - [signatureBytes]: 64-byte Ed25519 signature.
  /// - [publicKey]: 32-byte Ed25519 public key of the signer.
  ///
  /// Returns `true` if the signature is valid.
  static Future<bool> ed25519Verify({
    required Uint8List message,
    required Uint8List signatureBytes,
    required Uint8List publicKey,
  }) async {
    assert(signatureBytes.length == 64, 'Ed25519 signature must be 64 bytes');
    assert(publicKey.length == 32, 'Ed25519 public key must be 32 bytes');

    final signature = Signature(
      List<int>.from(signatureBytes),
      publicKey: SimplePublicKey(
        List<int>.from(publicKey),
        type: KeyPairType.ed25519,
      ),
    );

    return _ed25519.verify(message, signature: signature);
  }

  // -------------------------------------------------------------------------
  // HKDF-SHA256 — Key derivation
  // -------------------------------------------------------------------------

  /// Derive a symmetric key using HKDF-SHA256 (Extract + Expand combined).
  ///
  /// - [ikm]: Input Keying Material (the X25519 shared secret).
  /// - [salt]: Salt bytes (c_P ‖ c_L in the protocol).
  /// - [info]: Context/info bytes (e.g., "phone->esp" or "esp->phone").
  /// - [outputLength]: Desired output length in bytes (default: 32 for AES-256).
  ///
  /// The `cryptography` package's `Hkdf.deriveKey` performs both Extract and
  /// Expand in one call. Since HKDF-Extract is deterministic, calling this
  /// twice with the same (ikm, salt) but different info strings produces the
  /// same PRK internally and derives different output keys — exactly what our
  /// protocol needs for K_p2e and K_e2p.
  static Future<Uint8List> hkdfDerive({
    required Uint8List ikm,
    required Uint8List salt,
    required Uint8List info,
    int outputLength = ProtocolConstants.derivedKeyLength,
  }) async {
    final hkdf = Hkdf(
      hmac: _hmacSha256,
      outputLength: outputLength,
    );

    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKeyData(List<int>.from(ikm)),
      nonce: List<int>.from(salt),
      info: List<int>.from(info),
    );

    return Uint8List.fromList(derivedKey.bytes);
  }

  /// Convenience: derive both directional session keys from the protocol's
  /// shared secret and challenges.
  ///
  /// Returns `(phoneToEsp: K_p2e, espToPhone: K_e2p)`, each 32 bytes.
  static Future<({Uint8List phoneToEsp, Uint8List espToPhone})>
      deriveSessionKeys({
    required Uint8List sharedSecret,
    required Uint8List challengeP,
    required Uint8List challengeL,
  }) async {
    assert(sharedSecret.length == 32, 'Shared secret must be 32 bytes');
    assert(challengeP.length == 32, 'Challenge P must be 32 bytes');
    assert(challengeL.length == 32, 'Challenge L must be 32 bytes');

    // salt = c_P ‖ c_L (64 bytes)
    final salt = Uint8List(64);
    salt.setRange(0, 32, challengeP);
    salt.setRange(32, 64, challengeL);

    final infoP2E = Uint8List.fromList(
      utf8.encode(ProtocolConstants.hkdfInfoPhoneToEsp),
    );
    final infoE2P = Uint8List.fromList(
      utf8.encode(ProtocolConstants.hkdfInfoEspToPhone),
    );

    final phoneToEsp = await hkdfDerive(
      ikm: sharedSecret,
      salt: salt,
      info: infoP2E,
    );
    final espToPhone = await hkdfDerive(
      ikm: sharedSecret,
      salt: salt,
      info: infoE2P,
    );

    return (phoneToEsp: phoneToEsp, espToPhone: espToPhone);
  }

  // -------------------------------------------------------------------------
  // AES-256-GCM — Authenticated encryption
  // -------------------------------------------------------------------------

  /// Encrypt [plaintext] with AES-256-GCM.
  ///
  /// - [key]: 32-byte AES-256 key.
  /// - [plaintext]: data to encrypt (max 199 bytes per protocol).
  /// - [nonce]: optional 12-byte nonce; generated randomly if omitted.
  ///
  /// Returns the wire-format bytes: `nonce(12) ‖ ciphertext ‖ tag(16)`.
  /// Empty AAD is used (confirmed: Master §7.3).
  static Future<Uint8List> aesGcmEncrypt({
    required Uint8List key,
    required Uint8List plaintext,
    Uint8List? nonce,
  }) async {
    assert(key.length == 32, 'AES-256-GCM key must be 32 bytes');

    final secretKey = SecretKeyData(List<int>.from(key));
    final nonceBytes = nonce ?? Uint8List.fromList(_aesGcm.newNonce());

    assert(nonceBytes.length == ProtocolConstants.gcmNonceLength,
        'Nonce must be ${ProtocolConstants.gcmNonceLength} bytes');

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonceBytes,
      // Empty AAD — confirmed by master doc §7.3
    );

    // Wire format: nonce(12) ‖ ciphertext ‖ tag(16)
    return secretBox.concatenation();
  }

  /// Decrypt an AES-256-GCM wire-format payload.
  ///
  /// - [key]: 32-byte AES-256 key.
  /// - [encryptedPayload]: wire-format bytes `nonce(12) ‖ ciphertext ‖ tag(16)`.
  ///
  /// Returns the decrypted plaintext.
  /// Throws [SecretBoxAuthenticationError] if the GCM tag doesn't verify
  /// (caller should map this to [NfcSessionError.decryptionFailed]).
  static Future<Uint8List> aesGcmDecrypt({
    required Uint8List key,
    required Uint8List encryptedPayload,
  }) async {
    assert(key.length == 32, 'AES-256-GCM key must be 32 bytes');

    final secretKey = SecretKeyData(List<int>.from(key));

    // Parse wire format: nonce(12) ‖ ciphertext ‖ tag(16)
    final secretBox = SecretBox.fromConcatenation(
      encryptedPayload,
      nonceLength: ProtocolConstants.gcmNonceLength,
      macLength: ProtocolConstants.gcmTagLength,
      copy: false,
    );

    final clearText = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
      // Empty AAD
    );

    return Uint8List.fromList(clearText);
  }

  // -------------------------------------------------------------------------
  // Transcript — Domain-separated handshake transcript
  // -------------------------------------------------------------------------

  /// Build the domain-separated handshake transcript.
  ///
  /// Format: `"SLOCK-HS-v1" ‖ 0x01 ‖ pk_eph_P ‖ pk_eph_L ‖ c_P ‖ c_L`
  ///
  /// Total: 11 + 1 + 32 + 32 + 32 + 32 = 140 bytes.
  static Uint8List buildTranscript({
    required Uint8List pkEphP,
    required Uint8List pkEphL,
    required Uint8List challengeP,
    required Uint8List challengeL,
  }) {
    assert(pkEphP.length == 32);
    assert(pkEphL.length == 32);
    assert(challengeP.length == 32);
    assert(challengeL.length == 32);

    final prefix = utf8.encode(ProtocolConstants.transcriptPrefix);
    // prefix (11) + version (1) + 4 × 32 = 140
    final transcript = Uint8List(prefix.length + 1 + 128);
    var offset = 0;

    transcript.setRange(offset, offset + prefix.length, prefix);
    offset += prefix.length;

    transcript[offset] = ProtocolConstants.versionByte;
    offset += 1;

    transcript.setRange(offset, offset + 32, pkEphP);
    offset += 32;

    transcript.setRange(offset, offset + 32, pkEphL);
    offset += 32;

    transcript.setRange(offset, offset + 32, challengeP);
    offset += 32;

    transcript.setRange(offset, offset + 32, challengeL);
    // offset += 32; // final

    return transcript;
  }

  // -------------------------------------------------------------------------
  // Secure random
  // -------------------------------------------------------------------------

  /// Generate [length] cryptographically secure random bytes.
  static Uint8List generateSecureRandom(int length) {
    final rng = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }
}
