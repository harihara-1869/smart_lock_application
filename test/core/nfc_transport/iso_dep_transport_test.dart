import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/nfc_transport/fake_iso_dep_transport.dart';
import 'package:smartlock_application/core/nfc_transport/iso_dep_transport.dart';
import 'package:smartlock_application/core/result.dart';

void main() {
  late FakeIsoDepTransport transport;

  setUp(() {
    transport = FakeIsoDepTransport();
  });

  group('FakeIsoDepTransport', () {
    group('initial state', () {
      test('is not connected initially', () {
        expect(transport.isConnected, isFalse);
      });

      test('is not discovering initially', () {
        expect(transport.isDiscovering, isFalse);
      });

      test('has no enqueued entries initially', () {
        expect(transport.allConsumed, isTrue);
        expect(transport.remainingCount, 0);
      });
    });

    group('discovery lifecycle', () {
      test('startDiscovery returns Ok and sets discovering', () async {
        final result = await transport.startDiscovery();
        expect(result, isA<Ok>());
        expect(transport.isDiscovering, isTrue);
      });

      test('stopDiscovery clears discovering and connected states', () async {
        await transport.startDiscovery();
        transport.simulateTagDiscovered();
        expect(transport.isConnected, isTrue);

        await transport.stopDiscovery();
        expect(transport.isDiscovering, isFalse);
        expect(transport.isConnected, isFalse);
      });
    });

    group('tag discovery events', () {
      test('simulateTagDiscovered sets connected and emits event', () async {
        final events = <TransportEvent>[];
        transport.events.listen(events.add);

        transport.simulateTagDiscovered();

        await Future<void>.delayed(Duration.zero);
        expect(transport.isConnected, isTrue);
        expect(events, [const TransportEvent.tagDiscovered()]);
      });

      test('simulateTagLost clears connected and emits event', () async {
        final events = <TransportEvent>[];
        transport.events.listen(events.add);

        transport.simulateTagDiscovered();
        transport.simulateTagLost();

        await Future<void>.delayed(Duration.zero);
        expect(transport.isConnected, isFalse);
        expect(events, [
          const TransportEvent.tagDiscovered(),
          const TransportEvent.tagLost(),
        ]);
      });
    });

    group('transceive', () {
      test('returns notConnected when no tag is connected', () async {
        final result = await transport.transceive(Uint8List(0));
        expect(result, isA<Err>());
        final err = result as Err<Uint8List, TransportError>;
        expect(err.error, const TransportError.notConnected());
      });

      test('returns enqueued response in FIFO order', () async {
        transport.simulateTagDiscovered();
        transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));
        transport.enqueueResponse(Uint8List.fromList([0xAA, 0xBB, 0x90, 0x00]));

        final r1 = await transport.transceive(Uint8List.fromList([0x80, 0x10, 0x00, 0x00]));
        expect(r1, isA<Ok>());
        expect((r1 as Ok).value, orderedEquals([0x90, 0x00]));

        final r2 = await transport.transceive(Uint8List.fromList([0x80, 0x11, 0x00, 0x00]));
        expect(r2, isA<Ok>());
        expect((r2 as Ok).value, orderedEquals([0xAA, 0xBB, 0x90, 0x00]));

        expect(transport.allConsumed, isTrue);
      });

      test('throws StateError when queue is empty', () async {
        transport.simulateTagDiscovered();

        expect(
          () => transport.transceive(Uint8List.fromList([0x80, 0x10])),
          throwsStateError,
        );
      });

      test('validates expected command when specified', () async {
        transport.simulateTagDiscovered();
        transport.enqueue(
          Uint8List.fromList([0x80, 0x10, 0x00, 0x00]),
          Uint8List.fromList([0x90, 0x00]),
        );

        // Correct command works
        final result = await transport.transceive(
          Uint8List.fromList([0x80, 0x10, 0x00, 0x00]),
        );
        expect(result, isA<Ok>());
      });

      test('throws StateError on command mismatch', () async {
        transport.simulateTagDiscovered();
        transport.enqueue(
          Uint8List.fromList([0x80, 0x10, 0x00, 0x00]),
          Uint8List.fromList([0x90, 0x00]),
        );

        expect(
          () => transport.transceive(
            Uint8List.fromList([0x80, 0x11, 0x00, 0x00]), // Wrong INS
          ),
          throwsStateError,
        );
      });

      test('returns enqueued transport error', () async {
        transport.simulateTagDiscovered();
        transport.enqueueError(const TransportError.timeout());

        final result = await transport.transceive(Uint8List(1));
        expect(result, isA<Err>());
        final err = result as Err<Uint8List, TransportError>;
        expect(err.error, const TransportError.timeout());
      });

      test('tagLost error also disconnects and emits event', () async {
        final events = <TransportEvent>[];
        transport.events.listen(events.add);

        transport.simulateTagDiscovered();
        transport.enqueueError(const TransportError.tagLost());

        final result = await transport.transceive(Uint8List(1));
        expect(result, isA<Err>());

        await Future<void>.delayed(Duration.zero);
        expect(transport.isConnected, isFalse);
        expect(
          events,
          contains(const TransportEvent.tagLost()),
        );
      });
    });

    group('disconnect', () {
      test('emits tagLost and clears connected state', () async {
        final events = <TransportEvent>[];
        transport.events.listen(events.add);

        transport.simulateTagDiscovered();
        await transport.disconnect();

        await Future<void>.delayed(Duration.zero);
        expect(transport.isConnected, isFalse);
        expect(events.last, const TransportEvent.tagLost());
      });

      test('is a no-op when not connected', () async {
        final events = <TransportEvent>[];
        transport.events.listen(events.add);

        await transport.disconnect(); // Should not throw or emit

        await Future<void>.delayed(Duration.zero);
        // Only check that no tagLost was emitted
        expect(events.where((e) => e is TagLost), isEmpty);
      });
    });

    group('queue management', () {
      test('remainingCount tracks enqueued items', () {
        transport.enqueueResponse(Uint8List(0));
        transport.enqueueResponse(Uint8List(0));
        transport.enqueueError(const TransportError.timeout());
        expect(transport.remainingCount, 3);
      });

      test('allConsumed is false when entries remain', () {
        transport.enqueueResponse(Uint8List(0));
        expect(transport.allConsumed, isFalse);
      });
    });

    group('full handshake sequence simulation', () {
      test('M1 → M2, M3 → OK, scripted end-to-end', () async {
        transport.simulateTagDiscovered();

        // M1 command → M2 response (128 data bytes + SW 90 00)
        final m2Data = Uint8List(128);
        m2Data[0] = 0xDE; // Marker byte
        final m2Response = Uint8List.fromList([...m2Data, 0x90, 0x00]);
        transport.enqueueResponse(m2Response);

        // M3 command → OK response (empty data + SW 90 00)
        transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

        // Simulate M1 send
        final m1Capdu = Uint8List.fromList([
          0x80, 0x10, 0x00, 0x00, 0x40, // Header + Lc=64
          ...List.filled(64, 0xAA), // M1 data
        ]);
        final m2Result = await transport.transceive(m1Capdu);
        expect(m2Result, isA<Ok>());
        final m2Bytes = (m2Result as Ok<Uint8List, TransportError>).value;
        expect(m2Bytes.length, 130); // 128 data + 2 SW
        expect(m2Bytes[0], 0xDE);

        // Simulate M3 send
        final m3Capdu = Uint8List.fromList([
          0x80, 0x11, 0x00, 0x00, 0x40, // Header + Lc=64
          ...List.filled(64, 0xBB), // M3 data
        ]);
        final m3Result = await transport.transceive(m3Capdu);
        expect(m3Result, isA<Ok>());
        final m3Bytes = (m3Result as Ok<Uint8List, TransportError>).value;
        expect(m3Bytes.length, 2); // Just SW
        expect(m3Bytes[0], 0x90);
        expect(m3Bytes[1], 0x00);

        expect(transport.allConsumed, isTrue);
      });
    });
  });

  group('IsoDepTransport interface', () {
    test('FakeIsoDepTransport implements IsoDepTransport', () {
      // Type-level verification
      expect(transport, isA<IsoDepTransport>());
    });
  });

  group('TransportEvent', () {
    test('tagDiscovered equality', () {
      expect(
        const TransportEvent.tagDiscovered(),
        const TransportEvent.tagDiscovered(),
      );
    });

    test('tagLost equality', () {
      expect(
        const TransportEvent.tagLost(),
        const TransportEvent.tagLost(),
      );
    });

    test('different variants are not equal', () {
      expect(
        const TransportEvent.tagDiscovered(),
        isNot(const TransportEvent.tagLost()),
      );
    });
  });

  group('TransportError', () {
    test('all variants are constructible and distinct', () {
      final errors = <TransportError>[
        const TransportError.notConnected(),
        const TransportError.tagLost(),
        const TransportError.timeout(),
        const TransportError.transceiveFailed('test'),
        const TransportError.nfcUnavailable(),
      ];

      expect(errors.toSet().length, 5);
    });

    test('transceiveFailed carries message', () {
      const error = TransportError.transceiveFailed('broken');
      expect(error, isA<TransceiveFailed>());
      expect((error as TransceiveFailed).message, 'broken');
    });

    test('pattern matching is exhaustive', () {
      const error = TransportError.timeout();
      final label = switch (error) {
        TransportNotConnected() => 'notConnected',
        TransportTagLost() => 'tagLost',
        TransportTimeout() => 'timeout',
        TransceiveFailed() => 'transceiveFailed',
        NfcUnavailable() => 'nfcUnavailable',
      };
      expect(label, 'timeout');
    });
  });
}
