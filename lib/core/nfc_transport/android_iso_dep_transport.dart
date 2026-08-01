import 'dart:async';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:smartlock_application/core/nfc_transport/iso_dep_transport.dart';
import 'package:smartlock_application/core/result.dart';

/// Android implementation of [IsoDepTransport] backed by `nfc_manager` v4.2.1.
///
/// Uses [NfcManagerAndroid.enableReaderMode] for tag discovery with
/// `skipNdefCheck` and `noPlatformSounds` flags. On tag discovery, extracts
/// [IsoDepAndroid] for raw transceive. No `SELECT` (AID) step is performed —
/// M1 (INS 0x10) is the first application-level APDU after ISO-DEP activation.
///
/// The underlying Android `IsoDep` tag handle is valid from the
/// `onTagDiscovered` callback until the tag is lost or `disableReaderMode()`
/// is called — there is no explicit `connect()` / `close()` lifecycle.
class AndroidIsoDepTransport implements IsoDepTransport {
  AndroidIsoDepTransport({Logger? logger})
      : _logger = logger ?? Logger(printer: PrettyPrinter(methodCount: 0));

  final Logger _logger;
  final StreamController<TransportEvent> _eventController =
      StreamController<TransportEvent>.broadcast();

  /// The currently active ISO-DEP tag handle, or `null` if no tag is connected.
  IsoDepAndroid? _isoDep;

  /// Whether reader mode is currently enabled.
  bool _discovering = false;

  @override
  Stream<TransportEvent> get events => _eventController.stream;

  @override
  bool get isConnected => _isoDep != null;

  @override
  Future<Result<void, TransportError>> startDiscovery() async {
    if (_discovering) {
      _logger.w('startDiscovery called while already discovering');
      return const Result.ok(null);
    }

    try {
      // Check NFC availability via the cross-platform API.
      final availability = await NfcManager.instance.checkAvailability();
      if (availability != NfcAvailability.enabled) {
        _logger.e('NFC not available: $availability');
        return const Result.err(TransportError.nfcUnavailable());
      }

      // Use the Android-specific reader mode API for full control.
      await NfcManagerAndroid.instance.enableReaderMode(
        flags: {
          NfcReaderFlagAndroid.nfcA,
          NfcReaderFlagAndroid.nfcB,
          NfcReaderFlagAndroid.skipNdefCheck,
          NfcReaderFlagAndroid.noPlatformSounds,
        },
        onTagDiscovered: _onTagDiscovered,
      );

      _discovering = true;
      _logger.i('NFC reader mode enabled — scanning for ISO-DEP tags');
      return const Result.ok(null);
    } catch (e, st) {
      _logger.e('Failed to start NFC discovery', error: e, stackTrace: st);
      return Result.err(
        TransportError.transceiveFailed('Failed to start discovery: $e'),
      );
    }
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_discovering) return;

    try {
      await NfcManagerAndroid.instance.disableReaderMode();
      _logger.i('NFC reader mode disabled');
    } catch (e, st) {
      _logger.w('Error disabling reader mode', error: e, stackTrace: st);
    } finally {
      _discovering = false;
      _isoDep = null;
    }
  }

  @override
  Future<Result<Uint8List, TransportError>> transceive(
    Uint8List commandApdu,
  ) async {
    final tag = _isoDep;
    if (tag == null) {
      return const Result.err(TransportError.notConnected());
    }

    try {
      _logger.d(
        'TX [${commandApdu.length} bytes]: '
        '${_hexEncode(commandApdu)}',
      );

      final response = await tag.transceive(commandApdu);

      _logger.d(
        'RX [${response.length} bytes]: '
        '${_hexEncode(response)}',
      );

      return Result.ok(response);
    } catch (e, st) {
      _logger.e('Transceive failed', error: e, stackTrace: st);

      // Heuristic: if the transceive throws, the tag is likely lost.
      // Emit tagLost and clear the handle so subsequent calls fail cleanly.
      _handleTagLost();

      final message = e.toString();
      if (message.contains('TagLostException') ||
          message.contains('Tag was lost')) {
        return const Result.err(TransportError.tagLost());
      }
      if (message.contains('Timeout') || message.contains('timeout')) {
        return const Result.err(TransportError.timeout());
      }
      return Result.err(TransportError.transceiveFailed(message));
    }
  }

  @override
  Future<void> disconnect() async {
    if (_isoDep != null) {
      _handleTagLost();
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _onTagDiscovered(NfcTag tag) {
    final isoDep = IsoDepAndroid.from(tag);
    if (isoDep == null) {
      _logger.w('Discovered tag does not support ISO-DEP — ignoring');
      return;
    }

    _logger.i(
      'ISO-DEP tag discovered '
      '(extendedLength: ${isoDep.isExtendedLengthApduSupported})',
    );

    _isoDep = isoDep;
    _eventController.add(const TransportEvent.tagDiscovered());
  }

  void _handleTagLost() {
    if (_isoDep != null) {
      _isoDep = null;
      _eventController.add(const TransportEvent.tagLost());
      _logger.i('ISO-DEP tag lost');
    }
  }

  /// Hex-encode bytes for debug logging.
  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}
