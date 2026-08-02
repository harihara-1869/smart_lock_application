import 'dart:typed_data';

/// Physical lock state reported by CMD_GET_STATUS.
///
/// Source: APP_Development.md §4 — the `Lock_State` byte in the response.
enum LockState {
  /// 0x00 — bolt extended / locked.
  locked,

  /// 0x01 — bolt retracted / unlocked.
  unlocked,

  /// Anything else — firmware reported a value this app version doesn't know.
  unknown;

  /// Parse a raw lock-state byte.
  factory LockState.fromByte(int b) => switch (b) {
        0x00 => LockState.locked,
        0x01 => LockState.unlocked,
        _ => LockState.unknown,
      };
}

/// Parsed response from CMD_GET_STATUS.
///
/// Response plaintext (4 bytes):
/// ```
/// STATUS (1B) ‖ Battery_Pct (1B) ‖ Lock_State (1B) ‖ Last_Err (1B)
/// ```
///
/// The caller is responsible for checking that `data[0] == AppStatus.ok`
/// before constructing this class — [fromBytes] reads from index 1 onward.
class LockStatus {
  /// Battery charge level, 0–100 (percent).
  final int batteryPercent;

  /// Physical bolt position.
  final LockState lockState;

  /// Last error code the firmware recorded (0 = none).
  final int lastError;

  const LockStatus({
    required this.batteryPercent,
    required this.lockState,
    required this.lastError,
  });

  /// Parse from the decrypted CMD_GET_STATUS response (4 bytes).
  ///
  /// [data] must be at least 4 bytes. The caller should verify
  /// `data[0] == AppStatus.ok` before calling this factory.
  factory LockStatus.fromBytes(Uint8List data) {
    if (data.length < 4) {
      throw ArgumentError.value(
        data.length,
        'data.length',
        'CMD_GET_STATUS response must be at least 4 bytes '
            '(status ‖ battery ‖ state ‖ err)',
      );
    }

    return LockStatus(
      batteryPercent: data[1],
      lockState: LockState.fromByte(data[2]),
      lastError: data[3],
    );
  }
}
