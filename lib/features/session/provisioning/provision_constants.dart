abstract final class ProvisionConstants {
  static const int cmdProvision = 0x01;
  static const int provisionSecretLength = 32;
  static const int ed25519PubKeyLength = 32;
  // Request plaintext: opcode(1) + secret(32) + phone_pk(32) = 65 bytes
  static const int requestPlaintextLength = 65;
  // Response plaintext on success: status(1) + lock_pk(32) = 33 bytes
  static const int responseSuccessLength = 33;
}
