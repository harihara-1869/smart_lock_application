import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/session/commands/app_commands.dart';

void main() {
  group('AppCommands', () {
    test('opcodes match APP_Development.md §4', () {
      expect(AppCommands.cmdProvision, 0x01);
      expect(AppCommands.cmdUnlock, 0x02);
      expect(AppCommands.cmdLock, 0x03);
      expect(AppCommands.cmdGetStatus, 0x04);
      expect(AppCommands.cmdRevokeKey, 0x05);
    });

    test('opcodes are unique', () {
      final opcodes = [
        AppCommands.cmdProvision,
        AppCommands.cmdUnlock,
        AppCommands.cmdLock,
        AppCommands.cmdGetStatus,
        AppCommands.cmdRevokeKey,
      ];
      expect(opcodes.toSet().length, opcodes.length);
    });
  });

  group('AppStatus', () {
    test('status bytes match APP_Development.md §4', () {
      expect(AppStatus.ok, 0x00);
      expect(AppStatus.invalidSecret, 0x01);
      expect(AppStatus.unauthorized, 0x02);
      expect(AppStatus.invalidCmd, 0x03);
      expect(AppStatus.actuatorError, 0x04);
    });

    test('status bytes are unique', () {
      final statuses = [
        AppStatus.ok,
        AppStatus.invalidSecret,
        AppStatus.unauthorized,
        AppStatus.invalidCmd,
        AppStatus.actuatorError,
      ];
      expect(statuses.toSet().length, statuses.length);
    });
  });
}
