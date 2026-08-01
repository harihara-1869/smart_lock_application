// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nfc_errors.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NfcSessionError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcSessionError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NfcSessionError()';
}


}

/// @nodoc
class $NfcSessionErrorCopyWith<$Res>  {
$NfcSessionErrorCopyWith(NfcSessionError _, $Res Function(NfcSessionError) __);
}


/// Adds pattern-matching-related methods to [NfcSessionError].
extension NfcSessionErrorPatterns on NfcSessionError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( NfcTagLost value)?  tagLost,TResult Function( NfcTimeout value)?  timeout,TResult Function( NfcUnexpectedStatus value)?  unexpectedStatus,TResult Function( NfcAuthenticationFailed value)?  authenticationFailed,TResult Function( NfcHandshakeRejected value)?  handshakeRejected,TResult Function( NfcDecryptionFailed value)?  decryptionFailed,TResult Function( NfcInvalidState value)?  invalidState,TResult Function( NfcUntrustedLock value)?  untrustedLock,TResult Function( NfcNotAvailable value)?  nfcUnavailable,TResult Function( NfcPayloadTooLarge value)?  payloadTooLarge,TResult Function( NfcUnexpected value)?  unexpected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case NfcTagLost() when tagLost != null:
return tagLost(_that);case NfcTimeout() when timeout != null:
return timeout(_that);case NfcUnexpectedStatus() when unexpectedStatus != null:
return unexpectedStatus(_that);case NfcAuthenticationFailed() when authenticationFailed != null:
return authenticationFailed(_that);case NfcHandshakeRejected() when handshakeRejected != null:
return handshakeRejected(_that);case NfcDecryptionFailed() when decryptionFailed != null:
return decryptionFailed(_that);case NfcInvalidState() when invalidState != null:
return invalidState(_that);case NfcUntrustedLock() when untrustedLock != null:
return untrustedLock(_that);case NfcNotAvailable() when nfcUnavailable != null:
return nfcUnavailable(_that);case NfcPayloadTooLarge() when payloadTooLarge != null:
return payloadTooLarge(_that);case NfcUnexpected() when unexpected != null:
return unexpected(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( NfcTagLost value)  tagLost,required TResult Function( NfcTimeout value)  timeout,required TResult Function( NfcUnexpectedStatus value)  unexpectedStatus,required TResult Function( NfcAuthenticationFailed value)  authenticationFailed,required TResult Function( NfcHandshakeRejected value)  handshakeRejected,required TResult Function( NfcDecryptionFailed value)  decryptionFailed,required TResult Function( NfcInvalidState value)  invalidState,required TResult Function( NfcUntrustedLock value)  untrustedLock,required TResult Function( NfcNotAvailable value)  nfcUnavailable,required TResult Function( NfcPayloadTooLarge value)  payloadTooLarge,required TResult Function( NfcUnexpected value)  unexpected,}){
final _that = this;
switch (_that) {
case NfcTagLost():
return tagLost(_that);case NfcTimeout():
return timeout(_that);case NfcUnexpectedStatus():
return unexpectedStatus(_that);case NfcAuthenticationFailed():
return authenticationFailed(_that);case NfcHandshakeRejected():
return handshakeRejected(_that);case NfcDecryptionFailed():
return decryptionFailed(_that);case NfcInvalidState():
return invalidState(_that);case NfcUntrustedLock():
return untrustedLock(_that);case NfcNotAvailable():
return nfcUnavailable(_that);case NfcPayloadTooLarge():
return payloadTooLarge(_that);case NfcUnexpected():
return unexpected(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( NfcTagLost value)?  tagLost,TResult? Function( NfcTimeout value)?  timeout,TResult? Function( NfcUnexpectedStatus value)?  unexpectedStatus,TResult? Function( NfcAuthenticationFailed value)?  authenticationFailed,TResult? Function( NfcHandshakeRejected value)?  handshakeRejected,TResult? Function( NfcDecryptionFailed value)?  decryptionFailed,TResult? Function( NfcInvalidState value)?  invalidState,TResult? Function( NfcUntrustedLock value)?  untrustedLock,TResult? Function( NfcNotAvailable value)?  nfcUnavailable,TResult? Function( NfcPayloadTooLarge value)?  payloadTooLarge,TResult? Function( NfcUnexpected value)?  unexpected,}){
final _that = this;
switch (_that) {
case NfcTagLost() when tagLost != null:
return tagLost(_that);case NfcTimeout() when timeout != null:
return timeout(_that);case NfcUnexpectedStatus() when unexpectedStatus != null:
return unexpectedStatus(_that);case NfcAuthenticationFailed() when authenticationFailed != null:
return authenticationFailed(_that);case NfcHandshakeRejected() when handshakeRejected != null:
return handshakeRejected(_that);case NfcDecryptionFailed() when decryptionFailed != null:
return decryptionFailed(_that);case NfcInvalidState() when invalidState != null:
return invalidState(_that);case NfcUntrustedLock() when untrustedLock != null:
return untrustedLock(_that);case NfcNotAvailable() when nfcUnavailable != null:
return nfcUnavailable(_that);case NfcPayloadTooLarge() when payloadTooLarge != null:
return payloadTooLarge(_that);case NfcUnexpected() when unexpected != null:
return unexpected(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  tagLost,TResult Function()?  timeout,TResult Function( int sw1,  int sw2)?  unexpectedStatus,TResult Function()?  authenticationFailed,TResult Function()?  handshakeRejected,TResult Function()?  decryptionFailed,TResult Function( TransportState current,  String operation)?  invalidState,TResult Function()?  untrustedLock,TResult Function()?  nfcUnavailable,TResult Function( int size,  int maxSize)?  payloadTooLarge,TResult Function( String message)?  unexpected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case NfcTagLost() when tagLost != null:
return tagLost();case NfcTimeout() when timeout != null:
return timeout();case NfcUnexpectedStatus() when unexpectedStatus != null:
return unexpectedStatus(_that.sw1,_that.sw2);case NfcAuthenticationFailed() when authenticationFailed != null:
return authenticationFailed();case NfcHandshakeRejected() when handshakeRejected != null:
return handshakeRejected();case NfcDecryptionFailed() when decryptionFailed != null:
return decryptionFailed();case NfcInvalidState() when invalidState != null:
return invalidState(_that.current,_that.operation);case NfcUntrustedLock() when untrustedLock != null:
return untrustedLock();case NfcNotAvailable() when nfcUnavailable != null:
return nfcUnavailable();case NfcPayloadTooLarge() when payloadTooLarge != null:
return payloadTooLarge(_that.size,_that.maxSize);case NfcUnexpected() when unexpected != null:
return unexpected(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  tagLost,required TResult Function()  timeout,required TResult Function( int sw1,  int sw2)  unexpectedStatus,required TResult Function()  authenticationFailed,required TResult Function()  handshakeRejected,required TResult Function()  decryptionFailed,required TResult Function( TransportState current,  String operation)  invalidState,required TResult Function()  untrustedLock,required TResult Function()  nfcUnavailable,required TResult Function( int size,  int maxSize)  payloadTooLarge,required TResult Function( String message)  unexpected,}) {final _that = this;
switch (_that) {
case NfcTagLost():
return tagLost();case NfcTimeout():
return timeout();case NfcUnexpectedStatus():
return unexpectedStatus(_that.sw1,_that.sw2);case NfcAuthenticationFailed():
return authenticationFailed();case NfcHandshakeRejected():
return handshakeRejected();case NfcDecryptionFailed():
return decryptionFailed();case NfcInvalidState():
return invalidState(_that.current,_that.operation);case NfcUntrustedLock():
return untrustedLock();case NfcNotAvailable():
return nfcUnavailable();case NfcPayloadTooLarge():
return payloadTooLarge(_that.size,_that.maxSize);case NfcUnexpected():
return unexpected(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  tagLost,TResult? Function()?  timeout,TResult? Function( int sw1,  int sw2)?  unexpectedStatus,TResult? Function()?  authenticationFailed,TResult? Function()?  handshakeRejected,TResult? Function()?  decryptionFailed,TResult? Function( TransportState current,  String operation)?  invalidState,TResult? Function()?  untrustedLock,TResult? Function()?  nfcUnavailable,TResult? Function( int size,  int maxSize)?  payloadTooLarge,TResult? Function( String message)?  unexpected,}) {final _that = this;
switch (_that) {
case NfcTagLost() when tagLost != null:
return tagLost();case NfcTimeout() when timeout != null:
return timeout();case NfcUnexpectedStatus() when unexpectedStatus != null:
return unexpectedStatus(_that.sw1,_that.sw2);case NfcAuthenticationFailed() when authenticationFailed != null:
return authenticationFailed();case NfcHandshakeRejected() when handshakeRejected != null:
return handshakeRejected();case NfcDecryptionFailed() when decryptionFailed != null:
return decryptionFailed();case NfcInvalidState() when invalidState != null:
return invalidState(_that.current,_that.operation);case NfcUntrustedLock() when untrustedLock != null:
return untrustedLock();case NfcNotAvailable() when nfcUnavailable != null:
return nfcUnavailable();case NfcPayloadTooLarge() when payloadTooLarge != null:
return payloadTooLarge(_that.size,_that.maxSize);case NfcUnexpected() when unexpected != null:
return unexpected(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class NfcTagLost implements NfcSessionError {
  const NfcTagLost();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcTagLost);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NfcSessionError.tagLost()';
}


}




/// @nodoc


class NfcTimeout implements NfcSessionError {
  const NfcTimeout();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcTimeout);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NfcSessionError.timeout()';
}


}




/// @nodoc


class NfcUnexpectedStatus implements NfcSessionError {
  const NfcUnexpectedStatus(this.sw1, this.sw2);
  

 final  int sw1;
 final  int sw2;

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NfcUnexpectedStatusCopyWith<NfcUnexpectedStatus> get copyWith => _$NfcUnexpectedStatusCopyWithImpl<NfcUnexpectedStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcUnexpectedStatus&&(identical(other.sw1, sw1) || other.sw1 == sw1)&&(identical(other.sw2, sw2) || other.sw2 == sw2));
}


@override
int get hashCode => Object.hash(runtimeType,sw1,sw2);

@override
String toString() {
  return 'NfcSessionError.unexpectedStatus(sw1: $sw1, sw2: $sw2)';
}


}

/// @nodoc
abstract mixin class $NfcUnexpectedStatusCopyWith<$Res> implements $NfcSessionErrorCopyWith<$Res> {
  factory $NfcUnexpectedStatusCopyWith(NfcUnexpectedStatus value, $Res Function(NfcUnexpectedStatus) _then) = _$NfcUnexpectedStatusCopyWithImpl;
@useResult
$Res call({
 int sw1, int sw2
});




}
/// @nodoc
class _$NfcUnexpectedStatusCopyWithImpl<$Res>
    implements $NfcUnexpectedStatusCopyWith<$Res> {
  _$NfcUnexpectedStatusCopyWithImpl(this._self, this._then);

  final NfcUnexpectedStatus _self;
  final $Res Function(NfcUnexpectedStatus) _then;

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sw1 = null,Object? sw2 = null,}) {
  return _then(NfcUnexpectedStatus(
null == sw1 ? _self.sw1 : sw1 // ignore: cast_nullable_to_non_nullable
as int,null == sw2 ? _self.sw2 : sw2 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class NfcAuthenticationFailed implements NfcSessionError {
  const NfcAuthenticationFailed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcAuthenticationFailed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NfcSessionError.authenticationFailed()';
}


}




/// @nodoc


class NfcHandshakeRejected implements NfcSessionError {
  const NfcHandshakeRejected();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcHandshakeRejected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NfcSessionError.handshakeRejected()';
}


}




/// @nodoc


class NfcDecryptionFailed implements NfcSessionError {
  const NfcDecryptionFailed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcDecryptionFailed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NfcSessionError.decryptionFailed()';
}


}




/// @nodoc


class NfcInvalidState implements NfcSessionError {
  const NfcInvalidState(this.current, this.operation);
  

 final  TransportState current;
 final  String operation;

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NfcInvalidStateCopyWith<NfcInvalidState> get copyWith => _$NfcInvalidStateCopyWithImpl<NfcInvalidState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcInvalidState&&(identical(other.current, current) || other.current == current)&&(identical(other.operation, operation) || other.operation == operation));
}


@override
int get hashCode => Object.hash(runtimeType,current,operation);

@override
String toString() {
  return 'NfcSessionError.invalidState(current: $current, operation: $operation)';
}


}

/// @nodoc
abstract mixin class $NfcInvalidStateCopyWith<$Res> implements $NfcSessionErrorCopyWith<$Res> {
  factory $NfcInvalidStateCopyWith(NfcInvalidState value, $Res Function(NfcInvalidState) _then) = _$NfcInvalidStateCopyWithImpl;
@useResult
$Res call({
 TransportState current, String operation
});


$TransportStateCopyWith<$Res> get current;

}
/// @nodoc
class _$NfcInvalidStateCopyWithImpl<$Res>
    implements $NfcInvalidStateCopyWith<$Res> {
  _$NfcInvalidStateCopyWithImpl(this._self, this._then);

  final NfcInvalidState _self;
  final $Res Function(NfcInvalidState) _then;

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? current = null,Object? operation = null,}) {
  return _then(NfcInvalidState(
null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as TransportState,null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransportStateCopyWith<$Res> get current {
  
  return $TransportStateCopyWith<$Res>(_self.current, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}

/// @nodoc


class NfcUntrustedLock implements NfcSessionError {
  const NfcUntrustedLock();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcUntrustedLock);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NfcSessionError.untrustedLock()';
}


}




/// @nodoc


class NfcNotAvailable implements NfcSessionError {
  const NfcNotAvailable();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcNotAvailable);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NfcSessionError.nfcUnavailable()';
}


}




/// @nodoc


class NfcPayloadTooLarge implements NfcSessionError {
  const NfcPayloadTooLarge(this.size, this.maxSize);
  

 final  int size;
 final  int maxSize;

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NfcPayloadTooLargeCopyWith<NfcPayloadTooLarge> get copyWith => _$NfcPayloadTooLargeCopyWithImpl<NfcPayloadTooLarge>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcPayloadTooLarge&&(identical(other.size, size) || other.size == size)&&(identical(other.maxSize, maxSize) || other.maxSize == maxSize));
}


@override
int get hashCode => Object.hash(runtimeType,size,maxSize);

@override
String toString() {
  return 'NfcSessionError.payloadTooLarge(size: $size, maxSize: $maxSize)';
}


}

/// @nodoc
abstract mixin class $NfcPayloadTooLargeCopyWith<$Res> implements $NfcSessionErrorCopyWith<$Res> {
  factory $NfcPayloadTooLargeCopyWith(NfcPayloadTooLarge value, $Res Function(NfcPayloadTooLarge) _then) = _$NfcPayloadTooLargeCopyWithImpl;
@useResult
$Res call({
 int size, int maxSize
});




}
/// @nodoc
class _$NfcPayloadTooLargeCopyWithImpl<$Res>
    implements $NfcPayloadTooLargeCopyWith<$Res> {
  _$NfcPayloadTooLargeCopyWithImpl(this._self, this._then);

  final NfcPayloadTooLarge _self;
  final $Res Function(NfcPayloadTooLarge) _then;

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? size = null,Object? maxSize = null,}) {
  return _then(NfcPayloadTooLarge(
null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,null == maxSize ? _self.maxSize : maxSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class NfcUnexpected implements NfcSessionError {
  const NfcUnexpected(this.message);
  

 final  String message;

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NfcUnexpectedCopyWith<NfcUnexpected> get copyWith => _$NfcUnexpectedCopyWithImpl<NfcUnexpected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcUnexpected&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'NfcSessionError.unexpected(message: $message)';
}


}

/// @nodoc
abstract mixin class $NfcUnexpectedCopyWith<$Res> implements $NfcSessionErrorCopyWith<$Res> {
  factory $NfcUnexpectedCopyWith(NfcUnexpected value, $Res Function(NfcUnexpected) _then) = _$NfcUnexpectedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$NfcUnexpectedCopyWithImpl<$Res>
    implements $NfcUnexpectedCopyWith<$Res> {
  _$NfcUnexpectedCopyWithImpl(this._self, this._then);

  final NfcUnexpected _self;
  final $Res Function(NfcUnexpected) _then;

/// Create a copy of NfcSessionError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(NfcUnexpected(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
