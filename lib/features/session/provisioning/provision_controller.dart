import 'dart:typed_data';

import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/features/nfc/nfc_errors.dart';
import 'package:smartlock_application/features/session/commands/app_commands.dart';
import 'package:smartlock_application/features/session/handshake.dart';
import 'package:smartlock_application/features/session/identity_keystore.dart';
import 'package:smartlock_application/features/session/session_controller.dart';
import 'package:smartlock_application/features/session/trusted_locks_store.dart';
import 'package:smartlock_application/features/session/provisioning/provision_constants.dart';

/// Orchestrates the full provisioning flow.
class ProvisionController {
  final SessionController _sessionController;
  final IdentityKeystore _identityKeystore;
  final TrustedLocksStore _trustedLocksStore;

  ProvisionController({
    required SessionController sessionController,
    required IdentityKeystore identityKeystore,
    required TrustedLocksStore trustedLocksStore,
  })  : _sessionController = sessionController,
        _identityKeystore = identityKeystore,
        _trustedLocksStore = trustedLocksStore;

  /// Complete provisioning flow.
  Future<Result<void, NfcSessionError>> provisionLock({
    required String lockId,
    required Uint8List provisionSecret,
  }) async {
    // Start provisioning session (caches M2 without verifying)
    final sessionResult = await _sessionController.startProvisioningSession();
    if (sessionResult case Err(:final error)) {
      await _sessionController.abort();
      return Result.err(error);
    }

    try {
      final phoneIdentity = await _identityKeystore.getOrCreateIdentity();

      // Build CMD_PROVISION plaintext: [0x01] ‖ [Provision_Secret (32B)] ‖ [Phone_Ed25519_PK (32B)] = 65 bytes
      final plaintext = Uint8List(ProvisionConstants.requestPlaintextLength);
      plaintext[0] = ProvisionConstants.cmdProvision;
      plaintext.setRange(1, 33, provisionSecret);
      plaintext.setRange(33, 65, phoneIdentity.publicKey);

      // Send via sendSecureCommand
      final cmdResult = await _sessionController.sendSecureCommand(plaintext);
      
      final Uint8List decryptedResponse;
      switch (cmdResult) {
        case Ok(:final value):
          decryptedResponse = value;
        case Err(:final error):
          return Result.err(error);
      }

      if (decryptedResponse.isEmpty) {
        return const Result.err(NfcSessionError.unexpected('Empty response'));
      }

      final status = decryptedResponse[0];
      if (status != AppStatus.ok) {
        return Result.err(_mapProvisionStatus(status));
      }

      if (decryptedResponse.length != ProvisionConstants.responseSuccessLength) {
        return Result.err(NfcSessionError.unexpected('Invalid response length'));
      }

      // Extract lock_pk from response
      final lockPk = Uint8List.sublistView(decryptedResponse, 1, ProvisionConstants.responseSuccessLength);

      // Verify deferred M2 with lockPk
      final cachedM2 = _sessionController.deferredM2;
      if (cachedM2 == null) {
        return const Result.err(NfcSessionError.unexpected('Missing cached M2'));
      }

      final signatureValid = await Handshake.verifyDeferredM2(
        cached: cachedM2,
        lockPublicKey: lockPk,
      );

      if (!signatureValid) {
        return const Result.err(NfcSessionError.authenticationFailed());
      }

      // Store in TrustedLocksStore
      await _trustedLocksStore.storeTrustedKey(lockId, lockPk);
      
      return const Result.ok(null);
    } finally {
      await _sessionController.abort();
    }
  }

  NfcSessionError _mapProvisionStatus(int status) {
    return switch (status) {
      AppStatus.invalidSecret => const NfcSessionError.unexpected('invalid provision secret'),
      _ => NfcSessionError.unexpected('unknown app status: 0x${status.toRadixString(16)}'),
    };
  }

  /// Manually aborts the current session (e.g. if the user cancels).
  Future<void> abort() async {
    await _sessionController.abort();
  }
}
