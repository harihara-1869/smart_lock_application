import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/result.dart';

void main() {
  group('Result', () {
    test('Ok wraps a value', () {
      final result = Result<int, String>.ok(42);

      expect(result, isA<Ok<int, String>>());
      switch (result) {
        case Ok(:final value):
          expect(value, 42);
        case Err():
          fail('Expected Ok, got Err');
      }
    });

    test('Err wraps an error', () {
      final result = Result<int, String>.err('something went wrong');

      expect(result, isA<Err<int, String>>());
      switch (result) {
        case Ok():
          fail('Expected Err, got Ok');
        case Err(:final error):
          expect(error, 'something went wrong');
      }
    });

    test('pattern matching works exhaustively', () {
      final Result<int, String> ok = Result.ok(1);
      final Result<int, String> err = Result.err('fail');

      // This test primarily verifies that the sealed union compiles and
      // pattern-matches without warnings.
      final okResult = switch (ok) {
        Ok(:final value) => 'ok: $value',
        Err(:final error) => 'err: $error',
      };
      expect(okResult, 'ok: 1');

      final errResult = switch (err) {
        Ok(:final value) => 'ok: $value',
        Err(:final error) => 'err: $error',
      };
      expect(errResult, 'err: fail');
    });

    test('equality works for Ok', () {
      expect(Result<int, String>.ok(1), Result<int, String>.ok(1));
      expect(Result<int, String>.ok(1), isNot(Result<int, String>.ok(2)));
    });

    test('equality works for Err', () {
      expect(Result<int, String>.err('a'), Result<int, String>.err('a'));
      expect(
        Result<int, String>.err('a'),
        isNot(Result<int, String>.err('b')),
      );
    });

    test('Ok and Err are not equal even with matching inner values', () {
      // This is a type-level distinction, but good to verify
      final ok = Result<String, String>.ok('x');
      final err = Result<String, String>.err('x');
      expect(ok, isNot(equals(err)));
    });
  });
}
