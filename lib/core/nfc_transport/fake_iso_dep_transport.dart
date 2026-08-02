import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:smartlock_application/core/nfc_transport/iso_dep_transport.dart';
import 'package:smartlock_application/core/result.dart';

/// Scriptable entry for [FakeIsoDepTransport].
///
/// Each entry pairs an optional [expectedCommand] with a [response] (or a
/// [responseCallback] that dynamically builds the response from the incoming
/// command bytes). If [expectedCommand] is non-null, the transceive call's
/// command bytes are validated against it and a mismatch throws [StateError].
class FakeTransceiveEntry {
  FakeTransceiveEntry({
    this.expectedCommand,
    this.response,
    this.responseCallback,
  }) : assert(
          response != null || responseCallback != null,
          'Either response or responseCallback must be provided',
        );

  /// If non-null, the incoming command bytes must match exactly.
  final Uint8List? expectedCommand;

  /// The response to return — either [Result.ok] with bytes or [Result.err].
  /// Null when [responseCallback] is used instead.
  final Result<Uint8List, TransportError>? response;

  /// Dynamic response builder — receives the incoming command bytes and
  /// returns the response. Used when the scripted response depends on the
  /// command content (e.g. building a valid M2 from a random M1 ephemeral key).
  final Future<Result<Uint8List, TransportError>> Function(Uint8List)?
      responseCallback;
}

/// Scriptable test double for [IsoDepTransport].
///
/// Test code enqueues scripted [FakeTransceiveEntry] items (or errors),
/// then the system under test calls [transceive] which dequeues and returns
/// them in FIFO order. Provides helpers to simulate tag discovered/lost
/// events and to verify all enqueued entries were consumed.
///
/// Example:
/// ```dart
/// final fake = FakeIsoDepTransport();
/// fake.simulateTagDiscovered();
/// fake.enqueueResponse(Uint8List.fromList([0x90, 0x00]));
///
/// final result = await fake.transceive(someCapdu);
/// // result is Ok(Uint8List[0x90, 0x00])
/// ```
class FakeIsoDepTransport implements IsoDepTransport {
  final StreamController<TransportEvent> _eventController =
      StreamController<TransportEvent>.broadcast();

  final Queue<FakeTransceiveEntry> _queue = Queue<FakeTransceiveEntry>();

  bool _connected = false;
  bool _discovering = false;

  @override
  Stream<TransportEvent> get events => _eventController.stream;

  @override
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // IsoDepTransport implementation
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, TransportError>> startDiscovery() async {
    _discovering = true;
    return const Result.ok(null);
  }

  @override
  Future<void> stopDiscovery() async {
    _discovering = false;
    _connected = false;
  }

  @override
  Future<Result<Uint8List, TransportError>> transceive(
    Uint8List commandApdu,
  ) async {
    if (!_connected) {
      return const Result.err(TransportError.notConnected());
    }
    if (_queue.isEmpty) {
      throw StateError(
        'FakeIsoDepTransport: transceive called but no entries are enqueued. '
        'Command was: ${_hexEncode(commandApdu)}',
      );
    }

    final entry = _queue.removeFirst();

    // Validate expected command if specified.
    if (entry.expectedCommand != null) {
      final expected = entry.expectedCommand!;
      if (commandApdu.length != expected.length ||
          !_bytesEqual(commandApdu, expected)) {
        throw StateError(
          'FakeIsoDepTransport: command mismatch.\n'
          '  Expected: ${_hexEncode(expected)}\n'
          '  Actual:   ${_hexEncode(commandApdu)}',
        );
      }
    }

    // Generate the response — either dynamically via callback or from the
    // pre-scripted response field.
    final response = entry.responseCallback != null
        ? await entry.responseCallback!(commandApdu)
        : entry.response!;

    // If the scripted response is a tag-lost error, also update connected state.
    switch (response) {
      case Err(error: TransportTagLost()):
        _connected = false;
        _eventController.add(const TransportEvent.tagLost());
      default:
        break;
    }

    return response;
  }

  @override
  Future<void> disconnect() async {
    if (_connected) {
      _connected = false;
      _eventController.add(const TransportEvent.tagLost());
    }
  }

  // ---------------------------------------------------------------------------
  // Test helpers
  // ---------------------------------------------------------------------------

  /// Simulate an ISO-DEP tag being discovered.
  void simulateTagDiscovered() {
    _connected = true;
    _eventController.add(const TransportEvent.tagDiscovered());
  }

  /// Simulate the tag being lost externally (e.g., user moved phone away).
  void simulateTagLost() {
    _connected = false;
    _eventController.add(const TransportEvent.tagLost());
  }

  /// Enqueue a successful raw-bytes response for the next [transceive] call.
  void enqueueResponse(Uint8List responseBytes) {
    _queue.add(FakeTransceiveEntry(response: Result.ok(responseBytes)));
  }

  /// Enqueue a successful response with optional command validation.
  void enqueue(Uint8List expectedCommand, Uint8List responseBytes) {
    _queue.add(FakeTransceiveEntry(
      expectedCommand: expectedCommand,
      response: Result.ok(responseBytes),
    ));
  }

  /// Enqueue a transport error for the next [transceive] call.
  void enqueueError(TransportError error) {
    _queue.add(FakeTransceiveEntry(response: Result.err(error)));
  }

  /// Enqueue a dynamic callback that builds the response for the next
  /// [transceive] call based on the incoming command bytes.
  ///
  /// Used when the scripted response depends on the command content — e.g.
  /// building a valid M2 R-APDU from the phone's random M1 ephemeral key.
  void enqueueCallback(
    Future<Result<Uint8List, TransportError>> Function(Uint8List command)
        callback,
  ) {
    _queue.add(FakeTransceiveEntry(responseCallback: callback));
  }

  /// Whether all enqueued entries have been consumed.
  bool get allConsumed => _queue.isEmpty;

  /// Number of remaining enqueued entries.
  int get remainingCount => _queue.length;

  /// Whether discovery is currently active.
  bool get isDiscovering => _discovering;

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}
