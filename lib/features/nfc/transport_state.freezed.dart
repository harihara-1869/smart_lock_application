// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transport_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransportState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportState()';
}


}

/// @nodoc
class $TransportStateCopyWith<$Res>  {
$TransportStateCopyWith(TransportState _, $Res Function(TransportState) __);
}


/// Adds pattern-matching-related methods to [TransportState].
extension TransportStatePatterns on TransportState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TransportIdle value)?  idle,TResult Function( TransportActivated value)?  activated,TResult Function( TransportHandshake value)?  handshake,TResult Function( TransportSecureSession value)?  secureSession,TResult Function( TransportReleased value)?  released,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TransportIdle() when idle != null:
return idle(_that);case TransportActivated() when activated != null:
return activated(_that);case TransportHandshake() when handshake != null:
return handshake(_that);case TransportSecureSession() when secureSession != null:
return secureSession(_that);case TransportReleased() when released != null:
return released(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TransportIdle value)  idle,required TResult Function( TransportActivated value)  activated,required TResult Function( TransportHandshake value)  handshake,required TResult Function( TransportSecureSession value)  secureSession,required TResult Function( TransportReleased value)  released,}){
final _that = this;
switch (_that) {
case TransportIdle():
return idle(_that);case TransportActivated():
return activated(_that);case TransportHandshake():
return handshake(_that);case TransportSecureSession():
return secureSession(_that);case TransportReleased():
return released(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TransportIdle value)?  idle,TResult? Function( TransportActivated value)?  activated,TResult? Function( TransportHandshake value)?  handshake,TResult? Function( TransportSecureSession value)?  secureSession,TResult? Function( TransportReleased value)?  released,}){
final _that = this;
switch (_that) {
case TransportIdle() when idle != null:
return idle(_that);case TransportActivated() when activated != null:
return activated(_that);case TransportHandshake() when handshake != null:
return handshake(_that);case TransportSecureSession() when secureSession != null:
return secureSession(_that);case TransportReleased() when released != null:
return released(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  activated,TResult Function()?  handshake,TResult Function()?  secureSession,TResult Function()?  released,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TransportIdle() when idle != null:
return idle();case TransportActivated() when activated != null:
return activated();case TransportHandshake() when handshake != null:
return handshake();case TransportSecureSession() when secureSession != null:
return secureSession();case TransportReleased() when released != null:
return released();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  activated,required TResult Function()  handshake,required TResult Function()  secureSession,required TResult Function()  released,}) {final _that = this;
switch (_that) {
case TransportIdle():
return idle();case TransportActivated():
return activated();case TransportHandshake():
return handshake();case TransportSecureSession():
return secureSession();case TransportReleased():
return released();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  activated,TResult? Function()?  handshake,TResult? Function()?  secureSession,TResult? Function()?  released,}) {final _that = this;
switch (_that) {
case TransportIdle() when idle != null:
return idle();case TransportActivated() when activated != null:
return activated();case TransportHandshake() when handshake != null:
return handshake();case TransportSecureSession() when secureSession != null:
return secureSession();case TransportReleased() when released != null:
return released();case _:
  return null;

}
}

}

/// @nodoc


class TransportIdle implements TransportState {
  const TransportIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportState.idle()';
}


}




/// @nodoc


class TransportActivated implements TransportState {
  const TransportActivated();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportActivated);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportState.activated()';
}


}




/// @nodoc


class TransportHandshake implements TransportState {
  const TransportHandshake();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportHandshake);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportState.handshake()';
}


}




/// @nodoc


class TransportSecureSession implements TransportState {
  const TransportSecureSession();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportSecureSession);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportState.secureSession()';
}


}




/// @nodoc


class TransportReleased implements TransportState {
  const TransportReleased();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportReleased);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportState.released()';
}


}




// dart format on
