

/// Application-layer opcodes sent inside encrypted payloads (INS 0x20).
///
/// Source: APP_Development.md §4 — "Application Level Opcodes".
/// Request plaintext layout: `OPCODE (1B) ‖ PARAMETERS (...)`.
abstract final class AppCommands {
  /// Provision a new phone identity.
  /// Request: `Secret (32B) ‖ Phone_PK (32B)`.
  /// Response: `Status (1B) ‖ Lock_PK (32B)`.
  static const int cmdProvision = 0x01;

  /// Unlock the lock.
  /// Request: none (0B).
  /// Response: `Status (1B)`.
  static const int cmdUnlock = 0x02;

  /// Lock the lock.
  /// Request: none (0B).
  /// Response: `Status (1B)`.
  static const int cmdLock = 0x03;

  /// Query lock status.
  /// Request: none (0B).
  /// Response: `Status (1B) ‖ Battery_Pct (1B) ‖ Lock_State (1B) ‖ Last_Err (1B)`.
  static const int cmdGetStatus = 0x04;

  /// Revoke a phone's public key from the trusted store.
  /// Request: `Target_Phone_PK (32B)`.
  /// Response: `Status (1B)`.
  static const int cmdRevokeKey = 0x05;
}

/// Application-layer status bytes returned by the lock.
///
/// Source: APP_Development.md §4 — "Application Status Bytes".
/// These are encoded in the first byte of the decrypted response plaintext.
abstract final class AppStatus {
  /// Command executed successfully.
  static const int ok = 0x00;

  /// Provision Secret mismatched (CMD_PROVISION only).
  static const int invalidSecret = 0x01;

  /// Key not recognized or revoked.
  static const int unauthorized = 0x02;

  /// Unknown opcode or malformed parameters.
  static const int invalidCmd = 0x03;

  /// Mechanical jam or motor fault.
  static const int actuatorError = 0x04;
}
