// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Result<T,E> {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Result<T, E>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Result<$T, $E>()';
}


}

/// @nodoc
class $ResultCopyWith<T,E,$Res>  {
$ResultCopyWith(Result<T, E> _, $Res Function(Result<T, E>) __);
}


/// Adds pattern-matching-related methods to [Result].
extension ResultPatterns<T,E> on Result<T, E> {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Ok<T, E> value)?  ok,TResult Function( Err<T, E> value)?  err,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Ok() when ok != null:
return ok(_that);case Err() when err != null:
return err(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Ok<T, E> value)  ok,required TResult Function( Err<T, E> value)  err,}){
final _that = this;
switch (_that) {
case Ok():
return ok(_that);case Err():
return err(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Ok<T, E> value)?  ok,TResult? Function( Err<T, E> value)?  err,}){
final _that = this;
switch (_that) {
case Ok() when ok != null:
return ok(_that);case Err() when err != null:
return err(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( T value)?  ok,TResult Function( E error)?  err,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Ok() when ok != null:
return ok(_that.value);case Err() when err != null:
return err(_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( T value)  ok,required TResult Function( E error)  err,}) {final _that = this;
switch (_that) {
case Ok():
return ok(_that.value);case Err():
return err(_that.error);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( T value)?  ok,TResult? Function( E error)?  err,}) {final _that = this;
switch (_that) {
case Ok() when ok != null:
return ok(_that.value);case Err() when err != null:
return err(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class Ok<T,E> implements Result<T, E> {
  const Ok(this.value);
  

 final  T value;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OkCopyWith<T, E, Ok<T, E>> get copyWith => _$OkCopyWithImpl<T, E, Ok<T, E>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Ok<T, E>&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'Result<$T, $E>.ok(value: $value)';
}


}

/// @nodoc
abstract mixin class $OkCopyWith<T,E,$Res> implements $ResultCopyWith<T, E, $Res> {
  factory $OkCopyWith(Ok<T, E> value, $Res Function(Ok<T, E>) _then) = _$OkCopyWithImpl;
@useResult
$Res call({
 T value
});




}
/// @nodoc
class _$OkCopyWithImpl<T,E,$Res>
    implements $OkCopyWith<T, E, $Res> {
  _$OkCopyWithImpl(this._self, this._then);

  final Ok<T, E> _self;
  final $Res Function(Ok<T, E>) _then;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = freezed,}) {
  return _then(Ok<T, E>(
freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as T,
  ));
}


}

/// @nodoc


class Err<T,E> implements Result<T, E> {
  const Err(this.error);
  

 final  E error;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrCopyWith<T, E, Err<T, E>> get copyWith => _$ErrCopyWithImpl<T, E, Err<T, E>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Err<T, E>&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'Result<$T, $E>.err(error: $error)';
}


}

/// @nodoc
abstract mixin class $ErrCopyWith<T,E,$Res> implements $ResultCopyWith<T, E, $Res> {
  factory $ErrCopyWith(Err<T, E> value, $Res Function(Err<T, E>) _then) = _$ErrCopyWithImpl;
@useResult
$Res call({
 E error
});




}
/// @nodoc
class _$ErrCopyWithImpl<T,E,$Res>
    implements $ErrCopyWith<T, E, $Res> {
  _$ErrCopyWithImpl(this._self, this._then);

  final Err<T, E> _self;
  final $Res Function(Err<T, E>) _then;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = freezed,}) {
  return _then(Err<T, E>(
freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as E,
  ));
}


}

// dart format on
