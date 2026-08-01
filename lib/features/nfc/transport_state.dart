import 'package:freezed_annotation/freezed_annotation.dart';

part 'transport_state.freezed.dart';

/// Transport-layer state machine, mirroring the embedded `transport_state_t`.
///
/// State transitions:
/// ```
/// IDLE → ACTIVATED → HANDSHAKE → SECURE_SESSION → RELEASED
/// ```
///
/// Any state can also transition to RELEASED on error or abort.
@freezed
sealed class TransportState with _$TransportState {
  /// No NFC link — waiting for tag discovery.
  const factory TransportState.idle() = TransportIdle;

  /// ISO-DEP link established (post RATS/ATS), awaiting M1.
  const factory TransportState.activated() = TransportActivated;

  /// M1 sent, processing handshake (M2/M3 exchange).
  const factory TransportState.handshake() = TransportHandshake;

  /// Handshake complete — encrypted session established.
  const factory TransportState.secureSession() = TransportSecureSession;

  /// Session released — transport torn down.
  const factory TransportState.released() = TransportReleased;
}
