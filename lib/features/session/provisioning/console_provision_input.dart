import 'dart:typed_data';
import 'package:smartlock_application/features/session/provisioning/qr_provision_parser.dart';

/// Temporary: parse manually-entered hex secret.
/// Exactly the same as QrProvisionParser.parse — just a separate entry point
/// for the UI to distinguish the input source.
abstract final class ConsoleProvisionInput {
  static Uint8List? parseHexSecret(String hexSecret) {
    return QrProvisionParser.parse(hexSecret);
  }
}
