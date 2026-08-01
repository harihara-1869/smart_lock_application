import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:smartlock_application/features/nfc/protocol_constants.dart';

part 'apdu.freezed.dart';

/// Command APDU (C-APDU) sent from Phone to Lock.
///
/// Wire format: `CLA ‖ INS ‖ P1 ‖ P2 [‖ Lc ‖ Data]`
///
/// Case-3 APDU only — NO trailing Le byte (confirmed: transport.md's C-APDU
/// format is "CLA ‖ INS ‖ P1 ‖ P2 ‖ Lc ‖ Data", minimum 5 bytes with Lc=0
/// when no data). When data is empty, Lc is omitted (case-1 APDU: 4 bytes).
@freezed
abstract class Capdu with _$Capdu {
  const factory Capdu({
    required int cla,
    required int ins,
    required int p1,
    required int p2,
    required Uint8List data,
  }) = _Capdu;

  const Capdu._();

  /// Convenience factory using protocol-default CLA/P1/P2.
  factory Capdu.protocol({
    required int ins,
    Uint8List? data,
  }) {
    return Capdu(
      cla: ProtocolConstants.cla,
      ins: ins,
      p1: ProtocolConstants.p1,
      p2: ProtocolConstants.p2,
      data: data ?? Uint8List(0),
    );
  }

  /// Serializes to wire format bytes.
  ///
  /// If [data] is empty: `[CLA, INS, P1, P2]` (case-1 APDU, 4 bytes).
  /// If [data] is non-empty: `[CLA, INS, P1, P2, Lc, ...data]` (case-3 APDU).
  ///
  /// Throws [ArgumentError] if data length exceeds 255 (short APDU limit).
  Uint8List toBytes() {
    if (data.length > ProtocolConstants.maxCommandData) {
      throw ArgumentError.value(
        data.length,
        'data.length',
        'Exceeds short APDU max command data '
            '(${ProtocolConstants.maxCommandData})',
      );
    }

    if (data.isEmpty) {
      return Uint8List.fromList([cla, ins, p1, p2]);
    }

    final bytes = Uint8List(5 + data.length);
    bytes[0] = cla;
    bytes[1] = ins;
    bytes[2] = p1;
    bytes[3] = p2;
    bytes[4] = data.length;
    bytes.setRange(5, 5 + data.length, data);
    return bytes;
  }
}

/// Response APDU (R-APDU) received from Lock.
///
/// Wire format: `[Data...] SW1 SW2`
///
/// The last two bytes are always SW1 and SW2. Everything preceding them is
/// response data (which may be empty).
@freezed
abstract class Rapdu with _$Rapdu {
  const factory Rapdu({
    required Uint8List data,
    required int sw1,
    required int sw2,
  }) = _Rapdu;

  const Rapdu._();

  /// Parses wire format bytes into an [Rapdu].
  ///
  /// Throws [ArgumentError] if [bytes] is shorter than 2 bytes (must contain
  /// at least SW1 and SW2).
  factory Rapdu.fromBytes(Uint8List bytes) {
    if (bytes.length < 2) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'R-APDU must be at least 2 bytes (SW1 + SW2)',
      );
    }

    final sw1 = bytes[bytes.length - 2];
    final sw2 = bytes[bytes.length - 1];
    final data = bytes.length > 2
        ? Uint8List.sublistView(bytes, 0, bytes.length - 2)
        : Uint8List(0);

    return Rapdu(data: data, sw1: sw1, sw2: sw2);
  }

  /// Combined 16-bit status word for convenience.
  int get statusWord => (sw1 << 8) | sw2;

  /// Whether the response indicates success (SW 90 00).
  bool get isSuccess =>
      sw1 == 0x90 && sw2 == 0x00;

  /// Whether the response indicates authentication/signature failure (SW 69 82).
  bool get isAuthFailed =>
      sw1 == 0x69 && sw2 == 0x82;
}
