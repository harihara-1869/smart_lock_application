import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/nfc/status_word.dart';

void main() {
  group('StatusWord', () {
    group('fromBytes', () {
      test('recognizes success (90 00)', () {
        final sw = StatusWord.fromBytes(0x90, 0x00);
        expect(sw, StatusWord.ok);
        expect(sw.code, 0x9000);
        expect(sw.mnemonic, 'OK');
      });

      test('recognizes auth failed (69 82)', () {
        final sw = StatusWord.fromBytes(0x69, 0x82);
        expect(sw, StatusWord.authFailed);
        expect(sw.code, 0x6982);
        expect(sw.mnemonic, 'AUTH_FAILED');
      });

      test('recognizes wrong state (69 85)', () {
        final sw = StatusWord.fromBytes(0x69, 0x85);
        expect(sw, StatusWord.wrongState);
        expect(sw.code, 0x6985);
        expect(sw.mnemonic, 'WRONG_STATE');
      });

      test('recognizes invalid data (6A 80)', () {
        final sw = StatusWord.fromBytes(0x6A, 0x80);
        expect(sw, StatusWord.invalidData);
        expect(sw.code, 0x6A80);
        expect(sw.mnemonic, 'INVALID_DATA');
      });

      test('recognizes not supported (6A 81)', () {
        final sw = StatusWord.fromBytes(0x6A, 0x81);
        expect(sw, StatusWord.notSupported);
        expect(sw.code, 0x6A81);
        expect(sw.mnemonic, 'NOT_SUPPORTED');
      });

      test('returns unknown for unrecognized status words', () {
        final sw = StatusWord.fromBytes(0x67, 0x00);
        expect(sw, StatusWord.unknown);
        expect(sw.code, 0x0000);
        expect(sw.mnemonic, 'UNKNOWN');
      });

      test('returns unknown for arbitrary bytes', () {
        final sw = StatusWord.fromBytes(0xFF, 0xFF);
        expect(sw, StatusWord.unknown);
      });
    });

    group('enum values', () {
      test('all status words have unique codes (except unknown)', () {
        final codes = StatusWord.values
            .where((sw) => sw != StatusWord.unknown)
            .map((sw) => sw.code)
            .toSet();
        // 5 known status words (ok, authFailed, wrongState, invalidData,
        // notSupported) should all be unique.
        expect(codes.length, 5);
      });

      test('all status words have non-empty descriptions', () {
        for (final sw in StatusWord.values) {
          expect(sw.description, isNotEmpty);
          expect(sw.mnemonic, isNotEmpty);
        }
      });
    });
  });
}
