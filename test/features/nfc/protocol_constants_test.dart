import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';

void main() {
  group('ProtocolConstants', () {
    test('CLA is 0x80 (proprietary)', () {
      expect(ProtocolConstants.cla, 0x80);
    });

    test('P1 and P2 are 0x00', () {
      expect(ProtocolConstants.p1, 0x00);
      expect(ProtocolConstants.p2, 0x00);
    });

    test('INS codes are correct', () {
      expect(ProtocolConstants.insHandshakeInit, 0x10);
      expect(ProtocolConstants.insHandshakeFinish, 0x11);
      expect(ProtocolConstants.insSecurePayload, 0x20);
      expect(ProtocolConstants.insSessionAbort, 0x30);
    });

    test('version byte is 0x01', () {
      expect(ProtocolConstants.versionByte, 0x01);
    });

    test('M1 payload is 64 bytes (32 pk + 32 challenge)', () {
      expect(ProtocolConstants.m1Length, 64);
    });

    test('M2 payload is 128 bytes (32 pk + 32 challenge + 64 sig)', () {
      expect(ProtocolConstants.m2Length, 128);
    });

    test('M3 payload is 64 bytes (64 sig)', () {
      expect(ProtocolConstants.m3Length, 64);
    });

    test('max secure plaintext is 199 (227 - 12 nonce - 16 tag)', () {
      expect(ProtocolConstants.maxSecurePlaintext, 199);
      expect(
        ProtocolConstants.maxSecurePlaintext,
        ProtocolConstants.transportMaxLc -
            ProtocolConstants.gcmNonceLength -
            ProtocolConstants.gcmTagLength,
      );
    });

    test('derived key length is 32 (AES-256)', () {
      expect(ProtocolConstants.derivedKeyLength, 32);
    });

    test('transcript prefix is SLOCK-HS-v1', () {
      expect(ProtocolConstants.transcriptPrefix, 'SLOCK-HS-v1');
    });

    test('HKDF info strings match protocol spec', () {
      expect(ProtocolConstants.hkdfInfoPhoneToEsp, 'phone->esp');
      expect(ProtocolConstants.hkdfInfoEspToPhone, 'esp->phone');
    });
  });
}
