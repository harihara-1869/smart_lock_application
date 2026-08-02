/// Session-layer cryptographic primitives for the SLOCK-HS-v1 protocol.
///
/// This library exposes [CryptoPrimitives] — a pure-function utility class
/// wrapping X25519, Ed25519, HKDF-SHA256, and AES-256-GCM via the
/// `cryptography` package. No state, no I/O, no key storage.
library;

export 'crypto_primitives.dart';
