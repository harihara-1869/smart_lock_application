import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/nfc/transport_state.dart';

void main() {
  group('TransportState', () {
    test('all states are distinct', () {
      final states = [
        const TransportState.idle(),
        const TransportState.activated(),
        const TransportState.handshake(),
        const TransportState.secureSession(),
        const TransportState.released(),
      ];

      // Each state should be unique
      final unique = states.toSet();
      expect(unique.length, states.length);
    });

    test('pattern matching covers all states', () {
      const state = TransportState.secureSession();

      final label = switch (state) {
        TransportIdle() => 'idle',
        TransportActivated() => 'activated',
        TransportHandshake() => 'handshake',
        TransportSecureSession() => 'secure',
        TransportReleased() => 'released',
      };

      expect(label, 'secure');
    });

    test('same variant is equal', () {
      expect(
        const TransportState.idle(),
        const TransportState.idle(),
      );
      expect(
        const TransportState.secureSession(),
        const TransportState.secureSession(),
      );
    });

    test('different variants are not equal', () {
      expect(
        const TransportState.idle(),
        isNot(const TransportState.activated()),
      );
    });
  });
}
