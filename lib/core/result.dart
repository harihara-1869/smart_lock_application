import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';

/// A generic Result type for error-as-data at layer boundaries.
///
/// Use [Result.ok] for success values and [Result.err] for expected failures.
/// Callers should `switch`/pattern-match rather than `try/catch`.
@Freezed(genericArgumentFactories: true)
sealed class Result<T, E> with _$Result<T, E> {
  const factory Result.ok(T value) = Ok<T, E>;
  const factory Result.err(E error) = Err<T, E>;
}
