import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/nfc_transport/fake_iso_dep_transport.dart';
import 'package:smartlock_application/core/nfc_transport/iso_dep_transport.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';
import 'package:smartlock_application/features/nfc/transport_state.dart';
import 'package:smartlock_application/features/session/commands/app_commands.dart';
import 'package:smartlock_application/features/session/crypto/crypto_primitives.dart';
import 'package:smartlock_application/features/session/handshake.dart';
import 'package:smartlock_application/features/session/session_controller.dart';

/// Unwrap a Result, failing the test with [message] on Err.
T _unwrap<T, E>(Result<T, E> result, String message) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final error) => fail('$message: $error'),
  };
}

/// Simulated lock that dynamically builds M2 responses from the phone's M1
/// and handles secure-payload commands.
///
/// This mirrors what the lock firmware does (Master §7.3): generates an
/// ephemeral X25519 keypair, signs the transcript, derives session keys, and
/// decrypts/encrypts application payloads.
class _SimulatedLock {
  final Uint8List lockSeed;
  final Uint8List lockPublicKey;

  Uint8List? _ephPrivateKey;
  Uint8List? _challengeL;
  Uint8List? _kP2E;
  Uint8List? _kE2P;

  _SimulatedLock(this.lockSeed, this.lockPublicKey);

  /// Build the M2 R-APDU from the phone's M1 C-APDU bytes.
  ///
  /// C-APDU layout: CLA(1) INS(1) P1(1) P2(1) Lc(1) Data(64).
  Future<Uint8List> handleM1(Uint8List m1CapduBytes) async {
    final m1Payload = Uint8List.sublistView(m1CapduBytes, 5, 69);
    final pkEphP = Uint8List.sublistView(m1Payload, 0, 32);
    final challengeP = Uint8List.sublistView(m1Payload, 32, 64);

    final lockEph = await CryptoPrimitives.generateX25519KeyPair();
    _ephPrivateKey = lockEph.privateKey;
    _challengeL = CryptoPrimitives.generateSecureRandom(32);

    final transcript = CryptoPrimitives.buildTranscript(
      pkEphP: pkEphP,
      pkEphL: lockEph.publicKey,
      challengeP: challengeP,
      challengeL: _challengeL!,
    );

    final sigL = await CryptoPrimitives.ed25519Sign(
      message: transcript,
      privateKey: lockSeed,
      publicKey: lockPublicKey,
    );

    // Derive session keys from the lock's perspective.
    final sharedSecret = await CryptoPrimitives.x25519SharedSecret(
      localPrivateKey: lockEph.privateKey,
      remotePublicKey: pkEphP,
    );
    final keys = await CryptoPrimitives.deriveSessionKeys(
      sharedSecret: sharedSecret,
      challengeP: challengeP,
      challengeL: _challengeL!,
    );
    _kP2E = keys.phoneToEsp;
    _kE2P = keys.espToPhone;

    final m2Data = Uint8List(ProtocolConstants.m2Length)
      ..setRange(0, 32, lockEph.publicKey)
      ..setRange(32, 64, _challengeL!)
      ..setRange(64, 128, sigL);

    return Uint8List.fromList([...m2Data, 0x90, 0x00]);
  }

  /// Handle a secure-payload C-APDU, decrypting the command and encrypting
  /// the response.
  ///
  /// [respond] receives the decrypted plaintext and returns the response
  /// plaintext to encrypt.
  Future<Uint8List> handleSecurePayload(
    Uint8List cmdCapduBytes, {
    required Uint8List Function(Uint8List plaintext) respond,
  }) async {
    final encryptedPayload = Uint8List.sublistView(cmdCapduBytes, 5);

    final plaintext = await CryptoPrimitives.aesGcmDecrypt(
      key: _kP2E!,
      encryptedPayload: encryptedPayload,
    );

    final responsePlaintext = respond(plaintext);

    final encryptedResponse = await CryptoPrimitives.aesGcmEncrypt(
      key: _kE2P!,
      plaintext: responsePlaintext,
    );

    return Uint8List.fromList([...encryptedResponse, 0x90, 0x00]);
  }
}

/// Helper: build a controller with the given lock keypair and phone identity.
SessionController _buildController({
  required FakeIsoDepTransport transport,
  required Uint8List lockPublicKey,
  required Uint8List phoneSeed,
  required Uint8List phonePublicKey,
}) {
  return SessionController(
    transport: transport,
    resolveLockKey: (lockId) async =>
        lockId == 'lock1' ? lockPublicKey : null,
    resolvePhoneIdentity: () async =>
        (seed: phoneSeed, publicKey: phonePublicKey),
  );
}

/// Helper: pump the microtask queue so async code (startDiscovery, event
/// subscription) can progress before the test triggers tag discovery.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeIsoDepTransport transport;
  late Uint8List lockSeed;
  late Uint8List lockPublicKey;
  late Uint8List phoneSeed;
  late Uint8List phonePublicKey;

  setUp(() async {
    transport = FakeIsoDepTransport();
    final lockKp = await CryptoPrimitives.generateEd25519KeyPair();
    lockSeed = lockKp.privateKey;
    lockPublicKey = lockKp.publicKey;
    final phoneKp = await CryptoPrimitives.generateEd25519KeyPair();
    phoneSeed = phoneKp.privateKey;
    phonePublicKey = phoneKp.publicKey;
  });

  // ==========================================================================
  // Initial state & guards
  // ==========================================================================
  group('SessionController initial state', () {
    test('starts in idle state', () {
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );
      expect(controller.state, const TransportState.idle());
    });

    test('sendSecureCommand rejects when not in secureSession', () async {
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      final result = await controller.sendSecureCommand(
        Uint8List.fromList([AppCommands.cmdUnlock]),
      );

      expect(result, isA<Err<Uint8List, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcInvalidState>());
        case Ok(:final value):
          fail('Expected Err, got Ok');
      }
    });
  });

  // ==========================================================================
  // Normal session: startSession
  // ==========================================================================
  group('SessionController.startSession', () {
    test('completes handshake and reaches secureSession', () async {
      final lock = _SimulatedLock(lockSeed, lockPublicKey);
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      // M1 → M2 (dynamic callback)
      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );
      // M3 → ack (SW 90 00, empty data)
      transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

      final sessionFuture = controller.startSession(lockId: 'lock1');
      await _pump();
      transport.simulateTagDiscovered();

      final result = await sessionFuture;
      _unwrap(result, 'startSession should succeed');

      expect(controller.state, const TransportState.secureSession());
      expect(transport.allConsumed, isTrue);
    });

    test('returns untrustedLock for unknown lockId', () async {
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      final result = await controller.startSession(lockId: 'unknown');

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcUntrustedLock>());
        case Ok(:final value):
          fail('Expected Err, got Ok');
      }
    });

    test('returns authenticationFailed when M2 signature is bad', () async {
      final lock = _SimulatedLock(lockSeed, lockPublicKey);
      final controller = _buildController(
        transport: transport,
        // Wrong lock key → Sig_L won't verify
        lockPublicKey: (await CryptoPrimitives.generateEd25519KeyPair())
            .publicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );

      final sessionFuture = controller.startSession(lockId: 'lock1');
      await _pump();
      transport.simulateTagDiscovered();

      final result = await sessionFuture;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcAuthenticationFailed>());
        case Ok(:final value):
          fail('Expected Err, got Ok');
      }
      expect(controller.state, const TransportState.released());
    });

    test('returns handshakeRejected when M3 ack is SW 69 82', () async {
      final lock = _SimulatedLock(lockSeed, lockPublicKey);
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );
      // M3 → auth failed (SW 69 82)
      transport.enqueueResponse(Uint8List.fromList([0x69, 0x82]));

      final sessionFuture = controller.startSession(lockId: 'lock1');
      await _pump();
      transport.simulateTagDiscovered();

      final result = await sessionFuture;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcHandshakeRejected>());
        case Ok(:final value):
          fail('Expected Err, got Ok');
      }
      expect(controller.state, const TransportState.released());
    });

    test('maps tagLost transport error during M1', () async {
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      transport.enqueueError(const TransportError.tagLost());

      final sessionFuture = controller.startSession(lockId: 'lock1');
      await _pump();
      transport.simulateTagDiscovered();

      final result = await sessionFuture;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcTagLost>());
        case Ok(:final value):
          fail('Expected Err, got Ok');
      }
      expect(controller.state, const TransportState.released());
    });
  });

  // ==========================================================================
  // Secure command
  // ==========================================================================
  group('SessionController.sendSecureCommand', () {
    test('encrypts command and decrypts response', () async {
      final lock = _SimulatedLock(lockSeed, lockPublicKey);
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      // Handshake
      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );
      transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

      final sessionFuture = controller.startSession(lockId: 'lock1');
      await _pump();
      transport.simulateTagDiscovered();
      _unwrap(await sessionFuture, 'startSession should succeed');

      // Secure command: CMD_UNLOCK → response [AppStatus.ok]
      transport.enqueueCallback(
        (capdu) async => Result.ok(
          await lock.handleSecurePayload(
            capdu,
            respond: (plaintext) {
              expect(plaintext[0], AppCommands.cmdUnlock);
              return Uint8List.fromList([AppStatus.ok]);
            },
          ),
        ),
      );

      final cmdResult = await controller.sendSecureCommand(
        Uint8List.fromList([AppCommands.cmdUnlock]),
      );

      final response = _unwrap(cmdResult, 'sendSecureCommand should succeed');
      expect(response, orderedEquals([AppStatus.ok]));
      expect(transport.allConsumed, isTrue);
    });

    test('returns decryptionFailed on tampered response', () async {
      final lock = _SimulatedLock(lockSeed, lockPublicKey);
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      // Handshake
      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );
      transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

      final sessionFuture = controller.startSession(lockId: 'lock1');
      await _pump();
      transport.simulateTagDiscovered();
      _unwrap(await sessionFuture, 'startSession should succeed');

      // Return a valid-looking but wrongly-encrypted response.
      transport.enqueueCallback(
        (capdu) async {
          // Encrypt with a random key (not K_e2p) → tag won't verify.
          final wrongKey = CryptoPrimitives.generateSecureRandom(32);
          final encrypted = await CryptoPrimitives.aesGcmEncrypt(
            key: wrongKey,
            plaintext: Uint8List.fromList([AppStatus.ok]),
          );
          return Result.ok(Uint8List.fromList([...encrypted, 0x90, 0x00]));
        },
      );

      final cmdResult = await controller.sendSecureCommand(
        Uint8List.fromList([AppCommands.cmdUnlock]),
      );

      expect(cmdResult, isA<Err<Uint8List, NfcSessionError>>());
      switch (cmdResult) {
        case Err(:final error):
          expect(error, isA<NfcDecryptionFailed>());
        case Ok(:final value):
          fail('Expected Err, got Ok');
      }
      expect(controller.state, const TransportState.released());
    });
  });

  // ==========================================================================
  // Abort
  // ==========================================================================
  group('SessionController.abort', () {
    test('transitions to released from secureSession', () async {
      final lock = _SimulatedLock(lockSeed, lockPublicKey);
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      // Handshake
      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );
      transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

      final sessionFuture = controller.startSession(lockId: 'lock1');
      await _pump();
      transport.simulateTagDiscovered();
      _unwrap(await sessionFuture, 'startSession should succeed');

      // Abort: enqueue the abort ack
      transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));
      await controller.abort();

      expect(controller.state, const TransportState.released());
    });

    test('is a no-op from idle', () async {
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      final result = await controller.abort();

      expect(result, isA<Ok<void, NfcSessionError>>());
      expect(controller.state, const TransportState.released());
    });
  });

  // ==========================================================================
  // Provisioning session
  // ==========================================================================
  group('SessionController.startProvisioningSession', () {
    test('caches M2 without verification and reaches secureSession', () async {
      final lock = _SimulatedLock(lockSeed, lockPublicKey);
      final controller = _buildController(
        transport: transport,
        lockPublicKey: lockPublicKey,
        phoneSeed: phoneSeed,
        phonePublicKey: phonePublicKey,
      );

      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );
      transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

      final sessionFuture = controller.startProvisioningSession();
      await _pump();
      transport.simulateTagDiscovered();

      final result = await sessionFuture;
      _unwrap(result, 'startProvisioningSession should succeed');

      expect(controller.state, const TransportState.secureSession());

      // DeferredM2 is cached for Phase 8's deferred verification.
      expect(controller.deferredM2, isNotNull);
      expect(controller.deferredM2!.sigL.length, ProtocolConstants.ed25519SigLength);
      expect(controller.deferredM2!.transcript.length, 140);
    });
  });
}
