/// Protocol-level constants for the Smart Lock NFC communication protocol.
///
/// Values sourced from transport.md, session.md, lli.md, and comm_module.md.
abstract final class ProtocolConstants {
  // ---------------------------------------------------------------------------
  // CLA (confirmed: 0x80 proprietary — wrong CLA → SW 6A 81)
  // ---------------------------------------------------------------------------
  static const int cla = 0x80;
  static const int p1 = 0x00; // not validated by Transport; convention only
  static const int p2 = 0x00; // not validated by Transport; convention only

  // ---------------------------------------------------------------------------
  // INS codes (0x30 added from comm_module.md — session abort)
  // ---------------------------------------------------------------------------

  /// M1: Phone → Lock, valid in state ACTIVATED.
  static const int insHandshakeInit = 0x10;

  /// M3: Phone → Lock, valid in state HANDSHAKE.
  static const int insHandshakeFinish = 0x11;

  /// Secure payload exchange, valid in state SECURE_SESSION.
  static const int insSecurePayload = 0x20;

  /// Session abort, valid in ACTIVATED, HANDSHAKE, or SECURE_SESSION.
  static const int insSessionAbort = 0x30;

  // ---------------------------------------------------------------------------
  // Version byte (confirmed: 0x01)
  // ---------------------------------------------------------------------------
  static const int versionByte = 0x01;

  // ---------------------------------------------------------------------------
  // Size limits
  // ---------------------------------------------------------------------------
  static const int maxCommandData = 255; // Short APDU max command data
  static const int maxResponseData = 256; // Short APDU max response data
  static const int transportMaxLc = 227; // Enforced on nonce+ciphertext+tag
  static const int gcmNonceLength = 12;
  static const int gcmTagLength = 16;

  /// Maximum plaintext bytes that can be encrypted in a single secure payload.
  ///
  /// NOTE: session.md states "Maximum plaintext is 227 bytes (255 - 28 overhead),"
  /// which is internally inconsistent with transport.md's own Lc<=227 enforcement
  /// rule (227-28=199, not 255-28=227). Default to the smaller,
  /// arithmetically-consistent number until verified against real hardware —
  /// being wrong the other way fails loudly (SW 6A80) rather than silently,
  /// so 199 is the safe default.
  static const int maxSecurePlaintext =
      transportMaxLc - gcmNonceLength - gcmTagLength; // = 199

  // ---------------------------------------------------------------------------
  // Crypto sizes
  // ---------------------------------------------------------------------------
  static const int x25519KeyLength = 32;
  static const int ed25519PubKeyLength = 32;
  static const int ed25519SigLength = 64;
  static const int challengeLength = 32;

  // ---------------------------------------------------------------------------
  // Handshake payload sizes
  // ---------------------------------------------------------------------------

  /// M1 payload: pk_eph_P(32) ‖ c_P(32) = 64 bytes.
  static const int m1Length = x25519KeyLength + challengeLength;

  /// M2 payload: pk_eph_L(32) ‖ c_L(32) ‖ Sig_L(64) = 128 bytes.
  static const int m2Length =
      x25519KeyLength + challengeLength + ed25519SigLength;

  /// M3 payload: Sig_P(64) = 64 bytes.
  static const int m3Length = ed25519SigLength;

  // ---------------------------------------------------------------------------
  // HKDF / transcript
  // ---------------------------------------------------------------------------

  /// Prefix for the handshake transcript: "SLOCK-HS-v1".
  static const String transcriptPrefix = 'SLOCK-HS-v1';

  /// HKDF-Expand info string for Phone → ESP key.
  static const String hkdfInfoPhoneToEsp = 'phone->esp';

  /// HKDF-Expand info string for ESP → Phone key.
  static const String hkdfInfoEspToPhone = 'esp->phone';

  /// Derived key length for AES-256.
  static const int derivedKeyLength = 32;
}
