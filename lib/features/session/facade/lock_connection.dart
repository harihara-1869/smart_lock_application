import 'dart:typed_data';

import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/session/commands/app_commands.dart';
import 'package:smartlock_application/features/session/commands/lock_status.dart';
import 'package:smartlock_application/features/session/session_controller.dart';

/// Thin facade over [SessionController] providing typed command methods.
///
/// Each method starts a fresh NFC session (tap → handshake → command → abort),
/// matching the NFC tap-to-actuate model. Application-level failures (the lock
/// returning a non-OK status byte) are mapped to [NfcSessionError].
class LockConnection {
  final SessionController _controller;

  LockConnection(this._controller);

  /// Unlock the lock identified by [lockId].
  Future<Result<void, NfcSessionError>> unlock(String lockId) async {
    final result = await _runVoidCommand(
      lockId: lockId,
      plaintext: Uint8List.fromList([AppCommands.cmdUnlock]),
    );
    return result;
  }

  /// Lock the lock identified by [lockId].
  Future<Result<void, NfcSessionError>> lock(String lockId) async {
    final result = await _runVoidCommand(
      lockId: lockId,
      plaintext: Uint8List.fromList([AppCommands.cmdLock]),
    );
    return result;
  }

  /// Query the lock's status (battery, bolt position, last error).
  Future<Result<LockStatus, NfcSessionError>> getStatus(String lockId) async {
    final sessionResult = await _controller.startSession(lockId: lockId);
    if (sessionResult case Err(:final error)) {
      await _controller.abort();
      return Result.err(error);
    }

    try {
      final cmdResult = await _controller.sendSecureCommand(
        Uint8List.fromList([AppCommands.cmdGetStatus]),
      );
      return switch (cmdResult) {
        Ok(:final value) => _parseStatusResponse(value),
        Err(:final error) => Result.err(error),
      };
    } finally {
      await _controller.abort();
    }
  }

  /// Revoke a phone's public key from the lock's trusted store.
  Future<Result<void, NfcSessionError>> revokeKey(
    String lockId,
    Uint8List targetPublicKey,
  ) async {
    // Request plaintext: opcode(1) ‖ target_pk(32) = 33 bytes.
    final plaintext = Uint8List(33)
      ..[0] = AppCommands.cmdRevokeKey
      ..setRange(1, 33, targetPublicKey);

    final result = await _runVoidCommand(lockId: lockId, plaintext: plaintext);
    return result;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Run a command that expects an `AppStatus.ok` response byte.
  Future<Result<void, NfcSessionError>> _runVoidCommand({
    required String lockId,
    required Uint8List plaintext,
  }) async {
    final sessionResult = await _controller.startSession(lockId: lockId);
    if (sessionResult case Err()) {
      await _controller.abort();
      return sessionResult;
    }

    try {
      final cmdResult = await _controller.sendSecureCommand(plaintext);
      return switch (cmdResult) {
        Ok(:final value) => _checkOk(value),
        Err(:final error) => Result.err(error),
      };
    } finally {
      await _controller.abort();
    }
  }

  /// Check that the response starts with [AppStatus.ok].
  Result<void, NfcSessionError> _checkOk(Uint8List response) {
    if (response.isEmpty || response[0] != AppStatus.ok) {
      return Result.err(_mapAppStatus(response));
    }
    return const Result.ok(null);
  }

  /// Parse a CMD_GET_STATUS response into [LockStatus].
  Result<LockStatus, NfcSessionError> _parseStatusResponse(Uint8List response) {
    if (response.isEmpty || response[0] != AppStatus.ok) {
      return Result.err(_mapAppStatus(response));
    }
    try {
      return Result.ok(LockStatus.fromBytes(response));
    } catch (e) {
      return Result.err(NfcSessionError.unexpected('status parse error: $e'));
    }
  }

  /// Map a non-OK application status byte to an [NfcSessionError].
  NfcSessionError _mapAppStatus(Uint8List response) {
    if (response.isEmpty) {
      return const NfcSessionError.unexpected('empty app response');
    }
    final status = response[0];
    return switch (status) {
      AppStatus.invalidSecret =>
        const NfcSessionError.unexpected('invalid provision secret'),
      AppStatus.unauthorized => const NfcSessionError.authenticationFailed(),
      AppStatus.invalidCmd =>
        const NfcSessionError.unexpected('invalid command'),
      AppStatus.actuatorError =>
        const NfcSessionError.unexpected('actuator error'),
      _ => NfcSessionError.unexpected(
          'unknown app status: 0x${status.toRadixString(16)}'),
    };
  }
}
