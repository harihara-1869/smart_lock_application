import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/session/provisioning/qr_provision_parser.dart';

void main() {
  group('QrProvisionParser', () {
    test('Valid 64-char hex', () {
      final input = 'A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2';
      final result = QrProvisionParser.parse(input);
      expect(result, isNotNull);
      expect(result!.length, 32);
      expect(result[0], 0xA1);
      expect(result[31], 0xB2);
    });

    test('Valid lowercase hex', () {
      final input = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      final result = QrProvisionParser.parse(input);
      expect(result, isNotNull);
      expect(result!.length, 32);
      expect(result[0], 0xA1);
      expect(result[31], 0xB2);
    });

    test('Too short (62 chars)', () {
      final input = 'A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1';
      final result = QrProvisionParser.parse(input);
      expect(result, isNull);
    });

    test('Too long (66 chars)', () {
      final input = 'A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3';
      final result = QrProvisionParser.parse(input);
      expect(result, isNull);
    });

    test('Non-hex characters', () {
      final input = 'Z1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2';
      final result = QrProvisionParser.parse(input);
      expect(result, isNull);
    });

    test('Empty string', () {
      final result = QrProvisionParser.parse('');
      expect(result, isNull);
    });

    test('With whitespace', () {
      final input = ' A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2 ';
      final result = QrProvisionParser.parse(input);
      expect(result, isNotNull);
      expect(result!.length, 32);
    });
  });
}
