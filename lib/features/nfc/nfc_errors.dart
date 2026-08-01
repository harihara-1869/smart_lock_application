import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:smartlock_application/features/nfc/transport_state.dart';

part 'nfc_errors.freezed.dart';

/// All expected failure modes at the NFC/session feature boundary.
///
/// These are returned as [Result.err] values at layer boundaries — callers
/// should pattern-match over them rather than catching exceptions. Real
/// exceptions (`throw`) are reserved for programmer errors only.
@freezed
sealed class NfcSessionError with _$NfcSessionError {
  /// Tag was lost during NFC communication.
  const factory NfcSessionError.tagLost() = NfcTagLost;

  /// NFC transceive timed out.
  const factory NfcSessionError.timeout() = NfcTimeout;

  /// Lock returned an unexpected status word.
  const factory NfcSessionError.unexpectedStatus(int sw1, int sw2) =
      NfcUnexpectedStatus;

  /// Lock's M2 signature verification failed.
  const factory NfcSessionError.authenticationFailed() =
      NfcAuthenticationFailed;

  /// Lock rejected M3 (SW 69 82) — hard handshake failure, not retryable.
  const factory NfcSessionError.handshakeRejected() = NfcHandshakeRejected;

  /// AES-GCM tag mismatch on decryption — session is dead, do not retry with
  /// the same keys.
  const factory NfcSessionError.decryptionFailed() = NfcDecryptionFailed;

  /// Invalid transport state for the requested operation.
  const factory NfcSessionError.invalidState(
    TransportState current,
    String operation,
  ) = NfcInvalidState;

  /// Lock's public key is not in the trusted store.
  const factory NfcSessionError.untrustedLock() = NfcUntrustedLock;

  /// NFC hardware not available on this device.
  const factory NfcSessionError.nfcUnavailable() = NfcNotAvailable;

  /// Secure plaintext exceeds the 199-byte limit.
  const factory NfcSessionError.payloadTooLarge(int size, int maxSize) =
      NfcPayloadTooLarge;

  /// Unexpected error with diagnostic message.
  const factory NfcSessionError.unexpected(String message) = NfcUnexpected;
}
