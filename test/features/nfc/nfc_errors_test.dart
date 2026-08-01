import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/nfc/transport_state.dart';

void main() {
  group('NfcSessionError', () {
    test('all error variants are constructible', () {
      // Verify every variant can be instantiated without throwing
      final errors = <NfcSessionError>[
        const NfcSessionError.tagLost(),
        const NfcSessionError.timeout(),
        const NfcSessionError.unexpectedStatus(0x6A, 0x81),
        const NfcSessionError.authenticationFailed(),
        const NfcSessionError.handshakeRejected(),
        const NfcSessionError.decryptionFailed(),
        const NfcSessionError.invalidState(
          TransportState.idle(),
          'sendSecureCommand',
        ),
        const NfcSessionError.untrustedLock(),
        const NfcSessionError.nfcUnavailable(),
        const NfcSessionError.payloadTooLarge(250, 199),
        const NfcSessionError.unexpected('test error'),
      ];

      expect(errors.length, 11);
    });

    test('pattern matching covers all error types', () {
      const error = NfcSessionError.handshakeRejected();

      final label = switch (error) {
        NfcTagLost() => 'tagLost',
        NfcTimeout() => 'timeout',
        NfcUnexpectedStatus() => 'unexpectedStatus',
        NfcAuthenticationFailed() => 'authFailed',
        NfcHandshakeRejected() => 'handshakeRejected',
        NfcDecryptionFailed() => 'decryptionFailed',
        NfcInvalidState() => 'invalidState',
        NfcUntrustedLock() => 'untrustedLock',
        NfcNotAvailable() => 'nfcUnavailable',
        NfcPayloadTooLarge() => 'payloadTooLarge',
        NfcUnexpected() => 'unexpected',
      };

      expect(label, 'handshakeRejected');
    });

    test('unexpectedStatus carries SW1 and SW2', () {
      const error = NfcSessionError.unexpectedStatus(0x6A, 0x80);
      expect(error, isA<NfcUnexpectedStatus>());

      final status = error as NfcUnexpectedStatus;
      expect(status.sw1, 0x6A);
      expect(status.sw2, 0x80);
    });

    test('invalidState carries current state and operation', () {
      const error = NfcSessionError.invalidState(
        TransportState.idle(),
        'sendSecureCommand',
      );
      expect(error, isA<NfcInvalidState>());

      final invalid = error as NfcInvalidState;
      expect(invalid.current, const TransportState.idle());
      expect(invalid.operation, 'sendSecureCommand');
    });

    test('payloadTooLarge carries size and maxSize', () {
      const error = NfcSessionError.payloadTooLarge(250, 199);
      expect(error, isA<NfcPayloadTooLarge>());

      final payload = error as NfcPayloadTooLarge;
      expect(payload.size, 250);
      expect(payload.maxSize, 199);
    });

    test('unexpected carries message', () {
      const error = NfcSessionError.unexpected('something broke');
      expect(error, isA<NfcUnexpected>());

      final unexpected = error as NfcUnexpected;
      expect(unexpected.message, 'something broke');
    });

    test('equality works for same variant and parameters', () {
      expect(
        const NfcSessionError.tagLost(),
        const NfcSessionError.tagLost(),
      );
      expect(
        const NfcSessionError.unexpectedStatus(0x69, 0x82),
        const NfcSessionError.unexpectedStatus(0x69, 0x82),
      );
    });

    test('different variants are not equal', () {
      expect(
        const NfcSessionError.tagLost(),
        isNot(const NfcSessionError.timeout()),
      );
    });
  });
}
