import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/nfc/apdu.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';

void main() {
  group('Capdu', () {
    group('toBytes', () {
      test('case-1 APDU: header only when data is empty', () {
        final capdu = Capdu(
          cla: 0x80,
          ins: 0x10,
          p1: 0x00,
          p2: 0x00,
          data: Uint8List(0),
        );

        final bytes = capdu.toBytes();
        expect(bytes, orderedEquals([0x80, 0x10, 0x00, 0x00]));
        expect(bytes.length, 4);
      });

      test('case-3 APDU: header + Lc + data, no Le', () {
        final data = Uint8List.fromList([0x01, 0x02, 0x03]);
        final capdu = Capdu(
          cla: 0x80,
          ins: 0x20,
          p1: 0x00,
          p2: 0x00,
          data: data,
        );

        final bytes = capdu.toBytes();
        expect(
          bytes,
          orderedEquals([0x80, 0x20, 0x00, 0x00, 0x03, 0x01, 0x02, 0x03]),
        );
        expect(bytes.length, 8); // 4 header + 1 Lc + 3 data
      });

      test('no trailing Le byte is appended', () {
        final data = Uint8List.fromList([0xAA]);
        final capdu = Capdu(
          cla: 0x80,
          ins: 0x10,
          p1: 0x00,
          p2: 0x00,
          data: data,
        );

        final bytes = capdu.toBytes();
        // Should be exactly: CLA INS P1 P2 Lc Data — no extra byte
        expect(bytes.length, 6); // 4 header + 1 Lc + 1 data
        expect(bytes.last, 0xAA); // Last byte is data, not Le
      });

      test('Lc correctly encodes data length', () {
        final data = Uint8List(64); // M1 size
        final capdu = Capdu(
          cla: 0x80,
          ins: 0x10,
          p1: 0x00,
          p2: 0x00,
          data: data,
        );

        final bytes = capdu.toBytes();
        expect(bytes[4], 64); // Lc byte
        expect(bytes.length, 69); // 4 + 1 + 64
      });

      test('handles max short APDU data (255 bytes)', () {
        final data = Uint8List(255);
        final capdu = Capdu(
          cla: 0x80,
          ins: 0x20,
          p1: 0x00,
          p2: 0x00,
          data: data,
        );

        final bytes = capdu.toBytes();
        expect(bytes[4], 255); // Lc = 0xFF
        expect(bytes.length, 260); // 4 + 1 + 255
      });

      test('throws ArgumentError when data exceeds 255 bytes', () {
        final data = Uint8List(256);
        final capdu = Capdu(
          cla: 0x80,
          ins: 0x20,
          p1: 0x00,
          p2: 0x00,
          data: data,
        );

        expect(() => capdu.toBytes(), throwsArgumentError);
      });
    });

    group('Capdu.protocol factory', () {
      test('uses correct CLA, P1, P2 defaults', () {
        final capdu = Capdu.protocol(ins: 0x10);

        expect(capdu.cla, ProtocolConstants.cla);
        expect(capdu.ins, 0x10);
        expect(capdu.p1, ProtocolConstants.p1);
        expect(capdu.p2, ProtocolConstants.p2);
        expect(capdu.data, isEmpty);
      });

      test('accepts custom data', () {
        final data = Uint8List.fromList([0xDE, 0xAD]);
        final capdu = Capdu.protocol(ins: 0x20, data: data);

        expect(capdu.data, orderedEquals([0xDE, 0xAD]));
      });
    });

    group('freezed equality', () {
      test('two Capdus with same fields are equal', () {
        final a = Capdu.protocol(ins: 0x10, data: Uint8List.fromList([1, 2]));
        final b = Capdu.protocol(ins: 0x10, data: Uint8List.fromList([1, 2]));
        expect(a, equals(b));
      });

      test('two Capdus with different INS are not equal', () {
        final a = Capdu.protocol(ins: 0x10);
        final b = Capdu.protocol(ins: 0x11);
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('Rapdu', () {
    group('fromBytes', () {
      test('parses SW-only response (2 bytes)', () {
        final rapdu = Rapdu.fromBytes(Uint8List.fromList([0x90, 0x00]));

        expect(rapdu.data, isEmpty);
        expect(rapdu.sw1, 0x90);
        expect(rapdu.sw2, 0x00);
      });

      test('parses response with data + SW', () {
        final rapdu = Rapdu.fromBytes(
          Uint8List.fromList([0xAA, 0xBB, 0xCC, 0x90, 0x00]),
        );

        expect(rapdu.data, orderedEquals([0xAA, 0xBB, 0xCC]));
        expect(rapdu.sw1, 0x90);
        expect(rapdu.sw2, 0x00);
      });

      test('parses M2 response (128 data bytes + SW)', () {
        final m2Bytes = Uint8List(130); // 128 data + 2 SW
        m2Bytes[128] = 0x90;
        m2Bytes[129] = 0x00;
        m2Bytes[0] = 0xDE; // First data byte for verification

        final rapdu = Rapdu.fromBytes(m2Bytes);

        expect(rapdu.data.length, 128);
        expect(rapdu.data[0], 0xDE);
        expect(rapdu.isSuccess, isTrue);
      });

      test('parses auth failure response', () {
        final rapdu = Rapdu.fromBytes(Uint8List.fromList([0x69, 0x82]));

        expect(rapdu.data, isEmpty);
        expect(rapdu.isSuccess, isFalse);
        expect(rapdu.isAuthFailed, isTrue);
        expect(rapdu.statusWord, 0x6982);
      });

      test('throws ArgumentError for empty bytes', () {
        expect(
          () => Rapdu.fromBytes(Uint8List(0)),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError for single byte', () {
        expect(
          () => Rapdu.fromBytes(Uint8List.fromList([0x90])),
          throwsArgumentError,
        );
      });
    });

    group('statusWord', () {
      test('combines SW1 and SW2 correctly', () {
        final rapdu = Rapdu(
          data: Uint8List(0),
          sw1: 0x6A,
          sw2: 0x80,
        );
        expect(rapdu.statusWord, 0x6A80);
      });
    });

    group('isSuccess', () {
      test('true for 90 00', () {
        final rapdu = Rapdu(data: Uint8List(0), sw1: 0x90, sw2: 0x00);
        expect(rapdu.isSuccess, isTrue);
      });

      test('false for 69 82', () {
        final rapdu = Rapdu(data: Uint8List(0), sw1: 0x69, sw2: 0x82);
        expect(rapdu.isSuccess, isFalse);
      });
    });

    group('isAuthFailed', () {
      test('true for 69 82', () {
        final rapdu = Rapdu(data: Uint8List(0), sw1: 0x69, sw2: 0x82);
        expect(rapdu.isAuthFailed, isTrue);
      });

      test('false for 90 00', () {
        final rapdu = Rapdu(data: Uint8List(0), sw1: 0x90, sw2: 0x00);
        expect(rapdu.isAuthFailed, isFalse);
      });
    });

    group('serialization round-trip', () {
      test('toBytes → fromBytes preserves data and SW', () {
        // Build a C-APDU, pretend the response is the same bytes
        // (just testing Rapdu.fromBytes round-trip with known bytes)
        final originalData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final wireBytes = Uint8List.fromList([
          ...originalData,
          0x90,
          0x00,
        ]);

        final rapdu = Rapdu.fromBytes(wireBytes);
        expect(rapdu.data, orderedEquals(originalData));
        expect(rapdu.sw1, 0x90);
        expect(rapdu.sw2, 0x00);
      });
    });
  });
}
