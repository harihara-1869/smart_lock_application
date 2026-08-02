import 'dart:async';
import 'dart:typed_data';

import 'package:smartlock_application/core/nfc_transport/iso_dep_transport.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/apdu.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/nfc/protocol_constants.dart';
import 'package:smartlock_application/features/nfc/status_word.dart';
import 'package:smartlock_application/features/nfc/transport_state.dart';
import 'package:smartlock_application/features/session/handshake.dart';
import 'package:smartlock_application/features/session/secure_channel.dart';

/// Resolves a lock ID to the lock's Ed25519 public key (32 bytes), or `null`
/// if the lock is not in the trusted store.
///
/// Phase 7's `TrustedLocksStore.getLockPublicKey` satisfies this signature.
typedef LockKeyResolver =
    Future<Uint8List?> Function(String lockId);

/// Returns the phone's own long-term Ed25519 identity (32-byte seed + 32-byte
/// public key).
///
/// Phase 7's `IdentityKeystore.getOrCreateIdentity` satisfies this signature.
typedef PhoneIdentityResolver =
    Future<({Uint8List seed, Uint8List publicKey})> Function();

/// Orchestrates the full SLOCK-HS-v1 session lifecycle over an injected
/// [IsoDepTransport].
///
/// Owns:
/// - The [TransportState] state machine (idle → activated → handshake →
///   secureSession → released).
/// - A [SecureChannel] created after M3.
/// - A [HandshakeContext] created at M1 and consumed at M3.
///
/// All errors are returned as `Result<T, NfcSessionError>` — never thrown for
/// expected failures. The caller is responsible for calling [abort] to tear
/// down the session when done (or on error).
class SessionController {
  final IsoDepTransport _transport;
  final LockKeyResolver _resolveLockKey;
  final PhoneIdentityResolver _resolvePhoneIdentity;

  TransportState _state = const TransportState.idle();
  SecureChannel? _secureChannel;
  DeferredM2? _deferredM2;

  SessionController({
    required IsoDepTransport transport,
    required LockKeyResolver resolveLockKey,
    required PhoneIdentityResolver resolvePhoneIdentity,
  })  : _transport = transport,
        _resolveLockKey = resolveLockKey,
        _resolvePhoneIdentity = resolvePhoneIdentity;

  /// Current transport state (for diagnostics / UI).
  TransportState get state => _state;

  /// Cached M2 from the most recent provisioning session. Phase 8's
  /// `ProvisionController` reads this to verify the lock's deferred signature
  /// against the public key returned in the CMD_PROVISION response.
  DeferredM2? get deferredM2 => _deferredM2;

  // ---------------------------------------------------------------------------
  // Normal session
  // ---------------------------------------------------------------------------

  /// Establish a normal (authenticated) session with [lockId].
  ///
  /// 1. Look up the lock's Ed25519 public key.
  /// 2. Start NFC discovery and wait for a tag.
  /// 3. M1 → M2 (verify Sig_L) → M3 → secure session.
  Future<Result<void, NfcSessionError>> startSession({
    required String lockId,
  }) async {
    if (_state case TransportSecureSession() || TransportHandshake() ||
        TransportActivated()) {
      return Result.err(NfcSessionError.invalidState(_state, 'startSession'));
    }

    final lockPublicKey = await _resolveLockKey(lockId);
    if (lockPublicKey == null) {
      return const Result.err(NfcSessionError.untrustedLock());
    }

    final phoneIdentity = await _resolvePhoneIdentity();

    return _runHandshake(
      lockPublicKey: lockPublicKey,
      phoneIdentity: phoneIdentity,
    );
  }

  // ---------------------------------------------------------------------------
  // Provisioning session
  // ---------------------------------------------------------------------------

  /// Establish a provisioning session — same handshake but M2's Sig_L is
  /// cached (not verified) because the phone doesn't know the lock's public
  /// key yet.
  ///
  /// The cached [DeferredM2] is available via [deferredM2] for Phase 8's
  /// deferred verification after CMD_PROVISION.
  Future<Result<void, NfcSessionError>> startProvisioningSession() async {
    if (_state case TransportSecureSession() || TransportHandshake() ||
        TransportActivated()) {
      return Result.err(
        NfcSessionError.invalidState(_state, 'startProvisioningSession'),
      );
    }

    final phoneIdentity = await _resolvePhoneIdentity();

    return _runHandshake(
      lockPublicKey: null,
      phoneIdentity: phoneIdentity,
    );
  }

  // ---------------------------------------------------------------------------
  // Secure command
  // ---------------------------------------------------------------------------

  /// Send an encrypted application command and return the decrypted response.
  ///
  /// Precondition: state must be `secureSession`.
  /// The caller (facade) is responsible for checking the application status
  /// byte in the returned plaintext.
  Future<Result<Uint8List, NfcSessionError>> sendSecureCommand(
    Uint8List plaintext,
  ) async {
    if (_state is! TransportSecureSession) {
      return Result.err(
        NfcSessionError.invalidState(_state, 'sendSecureCommand'),
      );
    }

    final channel = _secureChannel!;

    // 1. Encrypt the plaintext command.
    final encResult = await channel.encrypt(plaintext);
    final Uint8List encryptedData;
    switch (encResult) {
      case Ok(:final value):
        encryptedData = value;
      case Err():
        return encResult;
    }

    // 2. Build & send the C-APDU (INS=0x20).
    final capdu = Capdu.protocol(
      ins: ProtocolConstants.insSecurePayload,
      data: encryptedData,
    );
    final xcvResult = await _transceive(capdu.toBytes());
    final Uint8List rawResponse;
    switch (xcvResult) {
      case Ok(:final value):
        rawResponse = value;
      case Err():
        return xcvResult;
    }

    // 3. Parse the R-APDU.
    final rapdu = Rapdu.fromBytes(rawResponse);
    if (!rapdu.isSuccess) {
      _release();
      return Result.err(_mapSecurePayloadStatus(rapdu));
    }

    // 4. Empty R-APDU data = lock internal failure (firmware §7.3 step 5).
    //    Return empty plaintext; the facade will treat it as an app error.
    if (rapdu.data.isEmpty) {
      return Result.ok(Uint8List(0));
    }

    // 5. Decrypt the response.
    final decResult = await channel.decrypt(rapdu.data);
    switch (decResult) {
      case Ok(:final value):
        return Result.ok(value);
      case Err():
        _release();
        return decResult;
    }
  }

  // ---------------------------------------------------------------------------
  // Abort
  // ---------------------------------------------------------------------------

  /// Tear down the session. Sends CMD_SESSION_ABORT (INS=0x30) best-effort
  /// and transitions to `released` regardless of the result.
  Future<Result<void, NfcSessionError>> abort() async {
    // INS=0x30 is valid in ACTIVATED, HANDSHAKE, or SECURE_SESSION.
    if (_state case TransportActivated() || TransportHandshake() ||
        TransportSecureSession()) {
      final capdu = Capdu.protocol(ins: ProtocolConstants.insSessionAbort);
      // Best-effort — we're tearing down regardless of the lock's response.
      try {
        await _transport.transceive(capdu.toBytes());
      } catch (_) {
        // Ignore: even a transport error here is fine, we're releasing.
      }
    }
    _release();
    return const Result.ok(null);
  }

  // ---------------------------------------------------------------------------
  // Internal: handshake runner
  // ---------------------------------------------------------------------------

  Future<Result<void, NfcSessionError>> _runHandshake({
    required Uint8List? lockPublicKey,
    required ({Uint8List seed, Uint8List publicKey}) phoneIdentity,
  }) async {
    _state = const TransportState.idle();
    _secureChannel = null;
    _deferredM2 = null;

    // --- Start discovery ---
    final discoveryResult = await _transport.startDiscovery();
    if (discoveryResult case Err(:final error)) {
      _release();
      return Result.err(_mapTransportError(error));
    }

    // --- Wait for tag ---
    final tagResult = await _waitForTag();
    if (tagResult case Err()) {
      _release();
      return tagResult;
    }
    _state = const TransportState.activated();

    // --- M1: build & send ---
    final (m1Payload, ctx) = await Handshake.buildM1();
    final m1Capdu = Capdu.protocol(
      ins: ProtocolConstants.insHandshakeInit,
      data: m1Payload,
    );
    final m1Result = await _transceive(m1Capdu.toBytes());
    final Uint8List m1Raw;
    switch (m1Result) {
      case Ok(:final value):
        m1Raw = value;
      case Err():
        _release();
        return m1Result;
    }

    final m1Rapdu = Rapdu.fromBytes(m1Raw);
    if (!m1Rapdu.isSuccess) {
      _release();
      return Result.err(_mapHandshakeStatus(m1Rapdu));
    }

    _state = const TransportState.handshake();

    // --- M2: parse & verify (or cache for provisioning) ---
    final Uint8List transcript;
    final Uint8List sharedSecret;
    final Uint8List challengeL;

    if (lockPublicKey != null) {
      // Normal session: verify Sig_L now.
      final m2Result = await Handshake.parseAndVerifyM2(
        m2Data: m1Rapdu.data,
        ctx: ctx,
        lockPublicKey: lockPublicKey,
      );
      switch (m2Result) {
        case Ok(:final value):
          transcript = value.transcript;
          sharedSecret = value.sharedSecret;
          challengeL = value.challengeL;
        case Err():
          _release();
          return m2Result;
      }
    } else {
      // Provisioning: cache without verifying.
      final m2Result = await Handshake.cacheM2ForProvisioning(
        m2Data: m1Rapdu.data,
        ctx: ctx,
      );
      switch (m2Result) {
        case Ok(:final value):
          _deferredM2 = value;
          transcript = value.transcript;
          sharedSecret = value.sharedSecret;
          challengeL = value.challengeL;
        case Err():
          _release();
          return m2Result;
      }
    }

    // --- M3: build & send ---
    final m3Result = await Handshake.buildM3(
      transcript: transcript,
      phoneSeed: phoneIdentity.seed,
      phonePublicKey: phoneIdentity.publicKey,
      sharedSecret: sharedSecret,
      challengeP: ctx.challengeP,
      challengeL: challengeL,
    );
    final m3Capdu = Capdu.protocol(
      ins: ProtocolConstants.insHandshakeFinish,
      data: m3Result.m3Payload,
    );
    final m3AckResult = await _transceive(m3Capdu.toBytes());
    final Uint8List m3AckRaw;
    switch (m3AckResult) {
      case Ok(:final value):
        m3AckRaw = value;
      case Err():
        _release();
        return m3AckResult;
    }

    final m3AckRapdu = Rapdu.fromBytes(m3AckRaw);
    if (!m3AckRapdu.isSuccess) {
      // SW 69 82 at M3 = lock couldn't verify Sig_P → handshakeRejected.
      _release();
      return Result.err(_mapM3Status(m3AckRapdu));
    }

    // --- Session established ---
    _secureChannel = SecureChannel(
      kP2E: m3Result.kP2E,
      kE2P: m3Result.kE2P,
    );
    _state = const TransportState.secureSession();

    return const Result.ok(null);
  }

  // ---------------------------------------------------------------------------
  // Internal: tag discovery wait
  // ---------------------------------------------------------------------------

  Future<Result<void, NfcSessionError>> _waitForTag() async {
    // If already connected (tag discovered before we started listening),
    // proceed immediately.
    if (_transport.isConnected) {
      return const Result.ok(null);
    }

    final completer = Completer<void>();
    late StreamSubscription<TransportEvent> sub;
    sub = _transport.events.listen(
      (event) {
        switch (event) {
          case TagDiscovered():
            if (!completer.isCompleted) {
              completer.complete();
            }
          case TagLost():
            if (!completer.isCompleted) {
              completer.completeError(const NfcSessionError.tagLost());
            }
        }
      },
      cancelOnError: true,
    );

    try {
      await completer.future;
      return const Result.ok(null);
    } on NfcSessionError catch (e) {
      return Result.err(e);
    } catch (e) {
      return Result.err(NfcSessionError.unexpected('event stream error: $e'));
    } finally {
      await sub.cancel();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal: transceive + transport error mapping
  // ---------------------------------------------------------------------------

  Future<Result<Uint8List, NfcSessionError>> _transceive(
    Uint8List capduBytes,
  ) async {
    final result = await _transport.transceive(capduBytes);
    return switch (result) {
      Ok(:final value) => Result.ok(value),
      Err(:final error) => Result.err(_mapTransportError(error)),
    };
  }

  NfcSessionError _mapTransportError(TransportError error) {
    return switch (error) {
      TransportTagLost() => const NfcSessionError.tagLost(),
      TransportTimeout() => const NfcSessionError.timeout(),
      TransportNotConnected() =>
        NfcSessionError.invalidState(_state, 'not connected'),
      NfcUnavailable() => const NfcSessionError.nfcUnavailable(),
      TransceiveFailed(:final message) => NfcSessionError.unexpected(message),
    };
  }

  // ---------------------------------------------------------------------------
  // Internal: status-word → NfcSessionError mapping (context-dependent)
  // ---------------------------------------------------------------------------

  /// Non-success SW during the handshake M1/M2 exchange.
  NfcSessionError _mapHandshakeStatus(Rapdu rapdu) {
    final sw = StatusWord.fromBytes(rapdu.sw1, rapdu.sw2);
    return switch (sw) {
      StatusWord.authFailed => const NfcSessionError.authenticationFailed(),
      StatusWord.wrongState =>
        NfcSessionError.invalidState(_state, 'lock rejected: wrong state'),
      StatusWord.invalidData =>
        NfcSessionError.unexpected('lock reports invalid data'),
      StatusWord.notSupported =>
        NfcSessionError.unexpected('lock reports INS not supported'),
      StatusWord.unknown ||
      StatusWord.ok =>
        NfcSessionError.unexpectedStatus(rapdu.sw1, rapdu.sw2),
    };
  }

  /// Non-success SW after sending M3 (INS=0x11).
  /// SW 69 82 here means the lock couldn't verify Sig_P.
  NfcSessionError _mapM3Status(Rapdu rapdu) {
    final sw = StatusWord.fromBytes(rapdu.sw1, rapdu.sw2);
    return switch (sw) {
      StatusWord.authFailed => const NfcSessionError.handshakeRejected(),
      StatusWord.wrongState =>
        NfcSessionError.invalidState(_state, 'lock rejected M3: wrong state'),
      StatusWord.invalidData =>
        NfcSessionError.unexpected('lock reports invalid M3 data'),
      StatusWord.notSupported =>
        NfcSessionError.unexpected('lock reports M3 INS not supported'),
      StatusWord.unknown ||
      StatusWord.ok =>
        NfcSessionError.unexpectedStatus(rapdu.sw1, rapdu.sw2),
    };
  }

  /// Non-success SW during a secure-payload exchange (INS=0x20).
  /// SW 69 82 here means an AES-GCM crypto failure — the session is dead.
  NfcSessionError _mapSecurePayloadStatus(Rapdu rapdu) {
    final sw = StatusWord.fromBytes(rapdu.sw1, rapdu.sw2);
    return switch (sw) {
      StatusWord.authFailed => const NfcSessionError.decryptionFailed(),
      StatusWord.wrongState => NfcSessionError.invalidState(
          _state,
          'lock rejected command: wrong state',
        ),
      StatusWord.invalidData =>
        NfcSessionError.unexpected('lock reports invalid payload'),
      StatusWord.notSupported =>
        NfcSessionError.unexpected('lock reports secure INS not supported'),
      StatusWord.unknown ||
      StatusWord.ok =>
        NfcSessionError.unexpectedStatus(rapdu.sw1, rapdu.sw2),
    };
  }

  // ---------------------------------------------------------------------------
  // Internal: state cleanup
  // ---------------------------------------------------------------------------

  void _release() {
    _state = const TransportState.released();
    _secureChannel = null;
    _deferredM2 = null;
  }
}
