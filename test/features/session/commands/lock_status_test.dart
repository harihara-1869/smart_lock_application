import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/session/commands/app_commands.dart';
import 'package:smartlock_application/features/session/commands/lock_status.dart';

void main() {
  group('LockState', () {
    test('fromByte maps 0x00 to locked', () {
      expect(LockState.fromByte(0x00), LockState.locked);
    });

    test('fromByte maps 0x01 to unlocked', () {
      expect(LockState.fromByte(0x01), LockState.unlocked);
    });

    test('fromByte maps unknown values to unknown', () {
      expect(LockState.fromByte(0x02), LockState.unknown);
      expect(LockState.fromByte(0xFF), LockState.unknown);
    });
  });

  group('LockStatus.fromBytes', () {
    test('parses valid 4-byte response', () {
      // status=ok, battery=85, state=locked, lastErr=0
      final data = Uint8List.fromList([
        AppStatus.ok,
        85,
        0x00, // locked
        0x00,
      ]);

      final status = LockStatus.fromBytes(data);

      expect(status.batteryPercent, 85);
      expect(status.lockState, LockState.locked);
      expect(status.lastError, 0x00);
    });

    test('parses unlocked state', () {
      final data = Uint8List.fromList([
        AppStatus.ok,
        50,
        0x01, // unlocked
        0x04, // actuator error
      ]);

      final status = LockStatus.fromBytes(data);

      expect(status.batteryPercent, 50);
      expect(status.lockState, LockState.unlocked);
      expect(status.lastError, 0x04);
    });

    test('throws ArgumentError for data shorter than 4 bytes', () {
      expect(
        () => LockStatus.fromBytes(Uint8List.fromList([0x00, 0x01, 0x02])),
        throwsArgumentError,
      );
    });

    test('accepts data longer than 4 bytes (reads first 4)', () {
      final data = Uint8List.fromList([
        AppStatus.ok,
        90,
        0x01,
        0x00,
        0xFF, // extra byte — ignored
      ]);

      final status = LockStatus.fromBytes(data);

      expect(status.batteryPercent, 90);
      expect(status.lockState, LockState.unlocked);
    });

    test('battery 0 and 100 are valid', () {
      final data0 = Uint8List.fromList([AppStatus.ok, 0, 0x00, 0x00]);
      final data100 = Uint8List.fromList([AppStatus.ok, 100, 0x01, 0x00]);

      expect(LockStatus.fromBytes(data0).batteryPercent, 0);
      expect(LockStatus.fromBytes(data100).batteryPercent, 100);
    });
  });
}
