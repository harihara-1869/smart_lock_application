import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/nfc_transport/fake_iso_dep_transport.dart';
import 'package:smartlock_application/core/nfc_transport/iso_dep_transport.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';
import 'package:smartlock_application/features/nfc/transport_state.dart';
import 'package:smartlock_application/features/session/commands/app_commands.dart';
import 'package:smartlock_application/features/session/commands/lock_status.dart';
import 'package:smartlock_application/features/session/crypto/crypto_primitives.dart';
import 'package:smartlock_application/features/session/facade/lock_connection.dart';
import 'package:smartlock_application/features/session/identity_keystore.dart';
import 'package:smartlock_application/features/session/provisioning/provision_constants.dart';
import 'package:smartlock_application/features/session/provisioning/provision_controller.dart';
import 'package:smartlock_application/features/session/session_controller.dart';
import 'package:smartlock_application/features/session/trusted_locks_store.dart';

import '../fake_flutter_secure_storage.dart';

// =============================================================================
// Test helpers
// =============================================================================

/// Unwrap a Result, failing the test with [message] on Err.
T _unwrap<T, E>(Result<T, E> result, String message) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final error) => fail('$message: $error'),
  };
}

/// Pump the microtask queue so the event subscription in `_waitForTag` is set
/// up before the test triggers `simulateTagDiscovered`.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

/// A full simulated lock firmware that dynamically handles M1, M3 acks, and
/// secure-payload commands — including CMD_PROVISION.
///
/// Mirrors the lock's behavior per Communication_Module_Master.md §7.3:
/// generates an ephemeral X25519 keypair at M1, signs the transcript, derives
/// session keys, then decrypts/encrypts application payloads.
class _SimulatedLock {
  final Uint8List lockSeed;
  final Uint8List lockPublicKey;
  final Uint8List? provisionSecret;

  Uint8List? _kP2E;
  Uint8List? _kE2P;

  _SimulatedLock({
    required this.lockSeed,
    required this.lockPublicKey,
    this.provisionSecret,
  });

  /// Build the M2 R-APDU from the phone's M1 C-APDU bytes.
  Future<Uint8List> handleM1(Uint8List m1CapduBytes) async {
    // C-APDU: CLA(1) INS(1) P1(1) P2(1) Lc(1) Data(64)
    final m1Payload = Uint8List.sublistView(m1CapduBytes, 5, 69);
    final pkEphP = Uint8List.sublistView(m1Payload, 0, 32);
    final challengeP = Uint8List.sublistView(m1Payload, 32, 64);

    final lockEph = await CryptoPrimitives.generateX25519KeyPair();
    final challengeL = CryptoPrimitives.generateSecureRandom(32);

    final transcript = CryptoPrimitives.buildTranscript(
      pkEphP: pkEphP,
      pkEphL: lockEph.publicKey,
      challengeP: challengeP,
      challengeL: challengeL,
    );

    final sigL = await CryptoPrimitives.ed25519Sign(
      message: transcript,
      privateKey: lockSeed,
      publicKey: lockPublicKey,
    );

    final sharedSecret = await CryptoPrimitives.x25519SharedSecret(
      localPrivateKey: lockEph.privateKey,
      remotePublicKey: pkEphP,
    );
    final keys = await CryptoPrimitives.deriveSessionKeys(
      sharedSecret: sharedSecret,
      challengeP: challengeP,
      challengeL: challengeL,
    );
    _kP2E = keys.phoneToEsp;
    _kE2P = keys.espToPhone;

    final m2Data = Uint8List(ProtocolConstants.m2Length)
      ..setRange(0, 32, lockEph.publicKey)
      ..setRange(32, 64, challengeL)
      ..setRange(64, 128, sigL);

    return Uint8List.fromList([...m2Data, 0x90, 0x00]);
  }

  /// Handle a secure-payload C-APDU. [respond] receives the decrypted command
  /// plaintext and returns the response plaintext to encrypt.
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

  /// Handle a CMD_PROVISION secure payload.
  ///
  /// Decrypts the 65-byte request, verifies the provision secret, and returns
  /// either `[0x00] ‖ lock_pk(32)` on success or `[0x01]` on secret mismatch.
  Future<Uint8List> handleProvision(Uint8List cmdCapduBytes) async {
    return handleSecurePayload(
      cmdCapduBytes,
      respond: (plaintext) {
        expect(plaintext[0], AppCommands.cmdProvision);
        final receivedSecret = Uint8List.sublistView(plaintext, 1, 33);

        if (provisionSecret != null &&
            _bytesEqual(receivedSecret, provisionSecret!)) {
          // Success: status(0x00) ‖ lock_pk(32)
          final response = Uint8List(ProvisionConstants.responseSuccessLength)
            ..[0] = AppStatus.ok
            ..setRange(1, 33, lockPublicKey);
          return response;
        }
        // Failure: invalid secret
        return Uint8List.fromList([AppStatus.invalidSecret]);
      },
    );
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Test fixture bundling all the real Phase 6–8 components wired together.
class _Fixture {
  final FakeIsoDepTransport transport;
  final IdentityKeystore identityKeystore;
  final TrustedLocksStore trustedLocksStore;
  final SessionController sessionController;
  final LockConnection lockConnection;
  final ProvisionController provisionController;

  _Fixture({
    required this.transport,
    required this.identityKeystore,
    required this.trustedLocksStore,
    required this.sessionController,
    required this.lockConnection,
    required this.provisionController,
  });
}

/// Build a fully-wired fixture with real keystores backed by a fake secure
/// storage. The trusted store is pre-populated with [lockPublicKey] under
/// 'lock1' so normal sessions can authenticate.
Future<_Fixture> _buildFixture({
  required Uint8List lockPublicKey,
}) async {
  final transport = FakeIsoDepTransport();
  final storage = FakeFlutterSecureStorage();
  final identityKeystore = IdentityKeystore(storage: storage);
  final trustedLocksStore = TrustedLocksStore(storage: storage);

  // Pre-populate the trusted store so normal sessions resolve the lock key.
  await trustedLocksStore.storeTrustedKey('lock1', lockPublicKey);

  final sessionController = SessionController(
    transport: transport,
    resolveLockKey: trustedLocksStore.getLockPublicKey,
    resolvePhoneIdentity: identityKeystore.getOrCreateIdentity,
  );
  final lockConnection = LockConnection(sessionController);
  final provisionController = ProvisionController(
    sessionController: sessionController,
    identityKeystore: identityKeystore,
    trustedLocksStore: trustedLocksStore,
  );

  return _Fixture(
    transport: transport,
    identityKeystore: identityKeystore,
    trustedLocksStore: trustedLocksStore,
    sessionController: sessionController,
    lockConnection: lockConnection,
    provisionController: provisionController,
  );
}

/// Enqueue a full normal-session handshake (M1 callback + M3 ack) on the
/// transport.
void _enqueueHandshake(FakeIsoDepTransport transport, _SimulatedLock lock) {
  transport.enqueueCallback(
    (capdu) async => Result.ok(await lock.handleM1(capdu)),
  );
  transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late Uint8List lockSeed;
  late Uint8List lockPublicKey;
  late Uint8List phoneSeed;
  late Uint8List phonePublicKey;

  setUp(() async {
    final lockKp = await CryptoPrimitives.generateEd25519KeyPair();
    lockSeed = lockKp.privateKey;
    lockPublicKey = lockKp.publicKey;
    final phoneKp = await CryptoPrimitives.generateEd25519KeyPair();
    phoneSeed = phoneKp.privateKey;
    phonePublicKey = phoneKp.publicKey;
  });

  group('Full session integration', () {
    // =========================================================================
    // Scenario 1: Happy path — handshake + unlock
    // =========================================================================
    test('scenario 1: happy path handshake + unlock', () async {
      final lock = _SimulatedLock(lockSeed: lockSeed, lockPublicKey: lockPublicKey);
      final f = await _buildFixture(lockPublicKey: lockPublicKey);

      _enqueueHandshake(f.transport, lock);
      // CMD_UNLOCK → response [AppStatus.ok]
      f.transport.enqueueCallback(
        (capdu) async => Result.ok(
          await lock.handleSecurePayload(
            capdu,
            respond: (pt) {
              expect(pt[0], AppCommands.cmdUnlock);
              return Uint8List.fromList([AppStatus.ok]);
            },
          ),
        ),
      );
      // Abort ack
      f.transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

      final future = f.lockConnection.unlock('lock1');
      await _pump();
      f.transport.simulateTagDiscovered();
      final result = await future;

      _unwrap(result, 'unlock should succeed');
      expect(f.transport.allConsumed, isTrue);
    });

    // =========================================================================
    // Scenario 2: M2 auth failure
    // =========================================================================
    test('scenario 2: M2 auth failure', () async {
      // Lock signs M2 with its real key, but the trusted store holds a
      // DIFFERENT key → Sig_L verification fails.
      final wrongKey = (await CryptoPrimitives.generateEd25519KeyPair()).publicKey;
      final lock = _SimulatedLock(lockSeed: lockSeed, lockPublicKey: lockPublicKey);
      final f = await _buildFixture(lockPublicKey: wrongKey);

      _enqueueHandshake(f.transport, lock);

      final future = f.lockConnection.unlock('lock1');
      await _pump();
      f.transport.simulateTagDiscovered();
      final result = await future;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcAuthenticationFailed>());
        case Ok():
          fail('Expected Err');
      }
      expect(f.sessionController.state, const TransportState.released());
    });

    // =========================================================================
    // Scenario 3: M3 rejection
    // =========================================================================
    test('scenario 3: M3 rejection (SW 69 82)', () async {
      final lock = _SimulatedLock(lockSeed: lockSeed, lockPublicKey: lockPublicKey);
      final f = await _buildFixture(lockPublicKey: lockPublicKey);

      // M1 → M2 ok, but M3 → SW 69 82 (lock couldn't verify Sig_P)
      f.transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );
      f.transport.enqueueResponse(Uint8List.fromList([0x69, 0x82]));

      final future = f.lockConnection.unlock('lock1');
      await _pump();
      f.transport.simulateTagDiscovered();
      final result = await future;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcHandshakeRejected>());
        case Ok():
          fail('Expected Err');
      }
      expect(f.sessionController.state, const TransportState.released());
    });

    // =========================================================================
    // Scenario 4: Tag lost during M1
    // =========================================================================
    test('scenario 4: tag lost during M1', () async {
      final f = await _buildFixture(lockPublicKey: lockPublicKey);

      // M1 transceive → tag lost
      f.transport.enqueueError(const TransportError.tagLost());

      final future = f.lockConnection.unlock('lock1');
      await _pump();
      f.transport.simulateTagDiscovered();
      final result = await future;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcTagLost>());
        case Ok():
          fail('Expected Err');
      }
      expect(f.sessionController.state, const TransportState.released());
    });

    // =========================================================================
    // Scenario 5: Timeout during M3
    // =========================================================================
    test('scenario 5: timeout during M3', () async {
      final lock = _SimulatedLock(lockSeed: lockSeed, lockPublicKey: lockPublicKey);
      final f = await _buildFixture(lockPublicKey: lockPublicKey);

      // M1 → M2 ok, but M3 ack → timeout
      f.transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleM1(capdu)),
      );
      f.transport.enqueueError(const TransportError.timeout());

      final future = f.lockConnection.unlock('lock1');
      await _pump();
      f.transport.simulateTagDiscovered();
      final result = await future;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcTimeout>());
        case Ok():
          fail('Expected Err');
      }
      expect(f.sessionController.state, const TransportState.released());
    });

    // =========================================================================
    // Scenario 6: Decrypt failure on command response
    // =========================================================================
    test('scenario 6: decrypt failure on command response', () async {
      final lock = _SimulatedLock(lockSeed: lockSeed, lockPublicKey: lockPublicKey);
      final f = await _buildFixture(lockPublicKey: lockPublicKey);

      _enqueueHandshake(f.transport, lock);
      // Return a valid-looking but wrongly-encrypted response → tag mismatch
      f.transport.enqueueCallback(
        (capdu) async {
          final wrongKey = CryptoPrimitives.generateSecureRandom(32);
          final encrypted = await CryptoPrimitives.aesGcmEncrypt(
            key: wrongKey,
            plaintext: Uint8List.fromList([AppStatus.ok]),
          );
          return Result.ok(Uint8List.fromList([...encrypted, 0x90, 0x00]));
        },
      );

      final future = f.lockConnection.unlock('lock1');
      await _pump();
      f.transport.simulateTagDiscovered();
      final result = await future;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcDecryptionFailed>());
        case Ok():
          fail('Expected Err');
      }
    });

    // =========================================================================
    // Scenario 7: Provisioning happy path
    // =========================================================================
    test('scenario 7: provisioning happy path stores trusted key', () async {
      final provisionSecret = CryptoPrimitives.generateSecureRandom(32);
      final lock = _SimulatedLock(
        lockSeed: lockSeed,
        lockPublicKey: lockPublicKey,
        provisionSecret: provisionSecret,
      );
      // Fresh fixture — trusted store is EMPTY (no pre-populated lock1).
      final transport = FakeIsoDepTransport();
      final storage = FakeFlutterSecureStorage();
      final identityKeystore = IdentityKeystore(storage: storage);
      final trustedLocksStore = TrustedLocksStore(storage: storage);
      final sessionController = SessionController(
        transport: transport,
        resolveLockKey: trustedLocksStore.getLockPublicKey,
        resolvePhoneIdentity: identityKeystore.getOrCreateIdentity,
      );
      final provisionController = ProvisionController(
        sessionController: sessionController,
        identityKeystore: identityKeystore,
        trustedLocksStore: trustedLocksStore,
      );

      // Handshake (provisioning mode: M2 cached, not verified)
      _enqueueHandshake(transport, lock);
      // CMD_PROVISION → response [0x00] ‖ [lock_pk]
      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleProvision(capdu)),
      );

      final future = provisionController.provisionLock(
        lockId: 'lock1',
        provisionSecret: provisionSecret,
      );
      await _pump();
      transport.simulateTagDiscovered();
      final result = await future;

      _unwrap(result, 'provisioning should succeed');

      // The lock's public key must now be stored in the trusted store.
      final storedKey = await trustedLocksStore.getLockPublicKey('lock1');
      expect(storedKey, isNotNull);
      expect(storedKey!, orderedEquals(lockPublicKey));
      expect(sessionController.state, const TransportState.released());
    });

    // =========================================================================
    // Scenario 8: Provisioning — bad secret
    // =========================================================================
    test('scenario 8: provisioning with bad secret is rejected', () async {
      final correctSecret = CryptoPrimitives.generateSecureRandom(32);
      final wrongSecret = CryptoPrimitives.generateSecureRandom(32);
      final lock = _SimulatedLock(
        lockSeed: lockSeed,
        lockPublicKey: lockPublicKey,
        provisionSecret: correctSecret,
      );
      final transport = FakeIsoDepTransport();
      final storage = FakeFlutterSecureStorage();
      final identityKeystore = IdentityKeystore(storage: storage);
      final trustedLocksStore = TrustedLocksStore(storage: storage);
      final sessionController = SessionController(
        transport: transport,
        resolveLockKey: trustedLocksStore.getLockPublicKey,
        resolvePhoneIdentity: identityKeystore.getOrCreateIdentity,
      );
      final provisionController = ProvisionController(
        sessionController: sessionController,
        identityKeystore: identityKeystore,
        trustedLocksStore: trustedLocksStore,
      );

      _enqueueHandshake(transport, lock);
      // CMD_PROVISION with wrong secret → response [0x01] (invalidSecret)
      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleProvision(capdu)),
      );

      final future = provisionController.provisionLock(
        lockId: 'lock1',
        provisionSecret: wrongSecret,
      );
      await _pump();
      transport.simulateTagDiscovered();
      final result = await future;

      expect(result, isA<Err<void, NfcSessionError>>());
      switch (result) {
        case Err(:final error):
          expect(error, isA<NfcUnexpected>());
        case Ok():
          fail('Expected Err');
      }
      // No key should have been stored.
      expect(await trustedLocksStore.getLockPublicKey('lock1'), isNull);
    });

    // =========================================================================
    // Scenario 9: Abort during secure session
    // =========================================================================
    test('scenario 9: abort during secure session', () async {
      final lock = _SimulatedLock(lockSeed: lockSeed, lockPublicKey: lockPublicKey);
      final f = await _buildFixture(lockPublicKey: lockPublicKey);

      _enqueueHandshake(f.transport, lock);

      final sessionFuture = f.sessionController.startSession(lockId: 'lock1');
      await _pump();
      f.transport.simulateTagDiscovered();
      _unwrap(await sessionFuture, 'startSession should succeed');
      expect(f.sessionController.state, const TransportState.secureSession());

      // Abort: enqueue ack
      f.transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));
      await f.sessionController.abort();

      expect(f.sessionController.state, const TransportState.released());
    });

    // =========================================================================
    // Scenario 10: CMD_GET_STATUS parse
    // =========================================================================
    test('scenario 10: CMD_GET_STATUS parses lock status', () async {
      final lock = _SimulatedLock(lockSeed: lockSeed, lockPublicKey: lockPublicKey);
      final f = await _buildFixture(lockPublicKey: lockPublicKey);

      _enqueueHandshake(f.transport, lock);
      // CMD_GET_STATUS → response [ok, battery=85, locked, err=0]
      f.transport.enqueueCallback(
        (capdu) async => Result.ok(
          await lock.handleSecurePayload(
            capdu,
            respond: (pt) {
              expect(pt[0], AppCommands.cmdGetStatus);
              return Uint8List.fromList([
                AppStatus.ok,
                85, // battery
                0x00, // locked
                0x00, // last error
              ]);
            },
          ),
        ),
      );
      f.transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

      final future = f.lockConnection.getStatus('lock1');
      await _pump();
      f.transport.simulateTagDiscovered();
      final result = await future;

      final status = _unwrap(result, 'getStatus should succeed');
      expect(status.batteryPercent, 85);
      expect(status.lockState, LockState.locked);
      expect(status.lastError, 0x00);
    });

    // =========================================================================
    // Bonus: Provision → Unlock cycle (full end-to-end wiring)
    // =========================================================================
    test('provision then unlock cycle (Phase 7+8 end-to-end)', () async {
      final provisionSecret = CryptoPrimitives.generateSecureRandom(32);
      final lock = _SimulatedLock(
        lockSeed: lockSeed,
        lockPublicKey: lockPublicKey,
        provisionSecret: provisionSecret,
      );

      // Fresh fixture — trusted store starts EMPTY.
      final storage = FakeFlutterSecureStorage();
      final identityKeystore = IdentityKeystore(storage: storage);
      final trustedLocksStore = TrustedLocksStore(storage: storage);
      final transport = FakeIsoDepTransport();
      final sessionController = SessionController(
        transport: transport,
        resolveLockKey: trustedLocksStore.getLockPublicKey,
        resolvePhoneIdentity: identityKeystore.getOrCreateIdentity,
      );
      final lockConnection = LockConnection(sessionController);
      final provisionController = ProvisionController(
        sessionController: sessionController,
        identityKeystore: identityKeystore,
        trustedLocksStore: trustedLocksStore,
      );

      // --- Phase 1: Provision the lock ---
      _enqueueHandshake(transport, lock);
      transport.enqueueCallback(
        (capdu) async => Result.ok(await lock.handleProvision(capdu)),
      );

      final provisionFuture = provisionController.provisionLock(
        lockId: 'lock1',
        provisionSecret: provisionSecret,
      );
      await _pump();
      transport.simulateTagDiscovered();
      _unwrap(await provisionFuture, 'provisioning should succeed');

      // Verify the key was stored.
      final storedKey = await trustedLocksStore.getLockPublicKey('lock1');
      expect(storedKey, isNotNull);
      expect(storedKey!, orderedEquals(lockPublicKey));

      // --- Phase 2: Unlock using the freshly-provisioned trusted key ---
      // The SessionController now resolves lock1's key from the store that
      // provisioning just populated.
      _enqueueHandshake(transport, lock);
      transport.enqueueCallback(
        (capdu) async => Result.ok(
          await lock.handleSecurePayload(
            capdu,
            respond: (pt) {
              expect(pt[0], AppCommands.cmdUnlock);
              return Uint8List.fromList([AppStatus.ok]);
            },
          ),
        ),
      );
      transport.enqueueResponse(Uint8List.fromList([0x90, 0x00]));

      final unlockFuture = lockConnection.unlock('lock1');
      await _pump();
      transport.simulateTagDiscovered();
      final unlockResult = await unlockFuture;

      _unwrap(unlockResult, 'unlock should succeed after provisioning');
      expect(transport.allConsumed, isTrue);
    });
  });
}
