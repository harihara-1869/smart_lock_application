// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'iso_dep_transport.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransportEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportEvent()';
}


}

/// @nodoc
class $TransportEventCopyWith<$Res>  {
$TransportEventCopyWith(TransportEvent _, $Res Function(TransportEvent) __);
}


/// Adds pattern-matching-related methods to [TransportEvent].
extension TransportEventPatterns on TransportEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TagDiscovered value)?  tagDiscovered,TResult Function( TagLost value)?  tagLost,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TagDiscovered() when tagDiscovered != null:
return tagDiscovered(_that);case TagLost() when tagLost != null:
return tagLost(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TagDiscovered value)  tagDiscovered,required TResult Function( TagLost value)  tagLost,}){
final _that = this;
switch (_that) {
case TagDiscovered():
return tagDiscovered(_that);case TagLost():
return tagLost(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TagDiscovered value)?  tagDiscovered,TResult? Function( TagLost value)?  tagLost,}){
final _that = this;
switch (_that) {
case TagDiscovered() when tagDiscovered != null:
return tagDiscovered(_that);case TagLost() when tagLost != null:
return tagLost(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  tagDiscovered,TResult Function()?  tagLost,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TagDiscovered() when tagDiscovered != null:
return tagDiscovered();case TagLost() when tagLost != null:
return tagLost();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  tagDiscovered,required TResult Function()  tagLost,}) {final _that = this;
switch (_that) {
case TagDiscovered():
return tagDiscovered();case TagLost():
return tagLost();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  tagDiscovered,TResult? Function()?  tagLost,}) {final _that = this;
switch (_that) {
case TagDiscovered() when tagDiscovered != null:
return tagDiscovered();case TagLost() when tagLost != null:
return tagLost();case _:
  return null;

}
}

}

/// @nodoc


class TagDiscovered implements TransportEvent {
  const TagDiscovered();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TagDiscovered);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportEvent.tagDiscovered()';
}


}




/// @nodoc


class TagLost implements TransportEvent {
  const TagLost();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TagLost);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportEvent.tagLost()';
}


}




/// @nodoc
mixin _$TransportError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportError()';
}


}

/// @nodoc
class $TransportErrorCopyWith<$Res>  {
$TransportErrorCopyWith(TransportError _, $Res Function(TransportError) __);
}


/// Adds pattern-matching-related methods to [TransportError].
extension TransportErrorPatterns on TransportError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TransportNotConnected value)?  notConnected,TResult Function( TransportTagLost value)?  tagLost,TResult Function( TransportTimeout value)?  timeout,TResult Function( TransceiveFailed value)?  transceiveFailed,TResult Function( NfcUnavailable value)?  nfcUnavailable,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TransportNotConnected() when notConnected != null:
return notConnected(_that);case TransportTagLost() when tagLost != null:
return tagLost(_that);case TransportTimeout() when timeout != null:
return timeout(_that);case TransceiveFailed() when transceiveFailed != null:
return transceiveFailed(_that);case NfcUnavailable() when nfcUnavailable != null:
return nfcUnavailable(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TransportNotConnected value)  notConnected,required TResult Function( TransportTagLost value)  tagLost,required TResult Function( TransportTimeout value)  timeout,required TResult Function( TransceiveFailed value)  transceiveFailed,required TResult Function( NfcUnavailable value)  nfcUnavailable,}){
final _that = this;
switch (_that) {
case TransportNotConnected():
return notConnected(_that);case TransportTagLost():
return tagLost(_that);case TransportTimeout():
return timeout(_that);case TransceiveFailed():
return transceiveFailed(_that);case NfcUnavailable():
return nfcUnavailable(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TransportNotConnected value)?  notConnected,TResult? Function( TransportTagLost value)?  tagLost,TResult? Function( TransportTimeout value)?  timeout,TResult? Function( TransceiveFailed value)?  transceiveFailed,TResult? Function( NfcUnavailable value)?  nfcUnavailable,}){
final _that = this;
switch (_that) {
case TransportNotConnected() when notConnected != null:
return notConnected(_that);case TransportTagLost() when tagLost != null:
return tagLost(_that);case TransportTimeout() when timeout != null:
return timeout(_that);case TransceiveFailed() when transceiveFailed != null:
return transceiveFailed(_that);case NfcUnavailable() when nfcUnavailable != null:
return nfcUnavailable(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  notConnected,TResult Function()?  tagLost,TResult Function()?  timeout,TResult Function( String message)?  transceiveFailed,TResult Function()?  nfcUnavailable,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TransportNotConnected() when notConnected != null:
return notConnected();case TransportTagLost() when tagLost != null:
return tagLost();case TransportTimeout() when timeout != null:
return timeout();case TransceiveFailed() when transceiveFailed != null:
return transceiveFailed(_that.message);case NfcUnavailable() when nfcUnavailable != null:
return nfcUnavailable();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  notConnected,required TResult Function()  tagLost,required TResult Function()  timeout,required TResult Function( String message)  transceiveFailed,required TResult Function()  nfcUnavailable,}) {final _that = this;
switch (_that) {
case TransportNotConnected():
return notConnected();case TransportTagLost():
return tagLost();case TransportTimeout():
return timeout();case TransceiveFailed():
return transceiveFailed(_that.message);case NfcUnavailable():
return nfcUnavailable();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  notConnected,TResult? Function()?  tagLost,TResult? Function()?  timeout,TResult? Function( String message)?  transceiveFailed,TResult? Function()?  nfcUnavailable,}) {final _that = this;
switch (_that) {
case TransportNotConnected() when notConnected != null:
return notConnected();case TransportTagLost() when tagLost != null:
return tagLost();case TransportTimeout() when timeout != null:
return timeout();case TransceiveFailed() when transceiveFailed != null:
return transceiveFailed(_that.message);case NfcUnavailable() when nfcUnavailable != null:
return nfcUnavailable();case _:
  return null;

}
}

}

/// @nodoc


class TransportNotConnected implements TransportError {
  const TransportNotConnected();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportNotConnected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportError.notConnected()';
}


}




/// @nodoc


class TransportTagLost implements TransportError {
  const TransportTagLost();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportTagLost);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportError.tagLost()';
}


}




/// @nodoc


class TransportTimeout implements TransportError {
  const TransportTimeout();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportTimeout);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportError.timeout()';
}


}




/// @nodoc


class TransceiveFailed implements TransportError {
  const TransceiveFailed(this.message);
  

 final  String message;

/// Create a copy of TransportError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransceiveFailedCopyWith<TransceiveFailed> get copyWith => _$TransceiveFailedCopyWithImpl<TransceiveFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransceiveFailed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'TransportError.transceiveFailed(message: $message)';
}


}

/// @nodoc
abstract mixin class $TransceiveFailedCopyWith<$Res> implements $TransportErrorCopyWith<$Res> {
  factory $TransceiveFailedCopyWith(TransceiveFailed value, $Res Function(TransceiveFailed) _then) = _$TransceiveFailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$TransceiveFailedCopyWithImpl<$Res>
    implements $TransceiveFailedCopyWith<$Res> {
  _$TransceiveFailedCopyWithImpl(this._self, this._then);

  final TransceiveFailed _self;
  final $Res Function(TransceiveFailed) _then;

/// Create a copy of TransportError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(TransceiveFailed(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NfcUnavailable implements TransportError {
  const NfcUnavailable();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NfcUnavailable);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransportError.nfcUnavailable()';
}


}




// dart format on
