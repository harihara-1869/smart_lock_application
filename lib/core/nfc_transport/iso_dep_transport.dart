import 'dart:async';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:smartlock_application/core/result.dart';

part 'iso_dep_transport.freezed.dart';

/// Events emitted by [IsoDepTransport] on connection state changes.
@freezed
sealed class TransportEvent with _$TransportEvent {
  /// An ISO-DEP tag has been discovered and is ready for transceive.
  const factory TransportEvent.tagDiscovered() = TagDiscovered;

  /// The connected ISO-DEP tag was lost.
  const factory TransportEvent.tagLost() = TagLost;
}

/// Errors that can occur during ISO-DEP transport operations.
@freezed
sealed class TransportError with _$TransportError {
  /// No tag is currently connected.
  const factory TransportError.notConnected() = TransportNotConnected;

  /// Tag was lost during a transceive operation.
  const factory TransportError.tagLost() = TransportTagLost;

  /// Transceive timed out.
  const factory TransportError.timeout() = TransportTimeout;

  /// General transceive failure with a diagnostic message.
  const factory TransportError.transceiveFailed(String message) =
      TransceiveFailed;

  /// NFC hardware is unavailable or disabled on this device.
  const factory TransportError.nfcUnavailable() = NfcUnavailable;
}

/// Abstract contract for low-level ISO-DEP (ISO 14443-4) NFC I/O.
///
/// Every layer above raw NFC depends on this interface rather than a concrete
/// implementation, enabling full unit testing via [FakeIsoDepTransport].
///
/// Usage lifecycle:
/// 1. Call [startDiscovery] to begin polling for ISO-DEP tags.
/// 2. Listen on [events] for [TagDiscovered].
/// 3. Call [transceive] to exchange raw APDU bytes.
/// 4. On [TagLost] or when done, call [stopDiscovery] / [disconnect].
abstract class IsoDepTransport {
  /// Stream of [TransportEvent]s — tag discovery and tag loss.
  Stream<TransportEvent> get events;

  /// Begin polling for ISO-DEP (ISO 14443-4) tags.
  ///
  /// Returns [TransportError.nfcUnavailable] if the hardware is off or missing.
  Future<Result<void, TransportError>> startDiscovery();

  /// Stop polling and release NFC resources.
  Future<void> stopDiscovery();

  /// Send [commandApdu] (raw C-APDU bytes) and return the raw R-APDU bytes.
  ///
  /// Precondition: [isConnected] must be `true`.
  Future<Result<Uint8List, TransportError>> transceive(Uint8List commandApdu);

  /// Whether an ISO-DEP tag is currently connected and ready for transceive.
  bool get isConnected;

  /// Force-release the current tag connection (no-op if not connected).
  Future<void> disconnect();
}
