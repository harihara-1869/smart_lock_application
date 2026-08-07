import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/core/widgets/primary_button.dart';

/// Revoke options presented to the user before a lock is removed.
enum RevokeScope {
  /// Remove the lock from this phone only. No NFC session is started.
  phoneOnly,

  /// Remove the lock from this phone AND send `CMD_REVOKE_KEY` to the lock so
  /// its authorized-key store forgets this phone's identity too.
  lockAndPhone,
}

/// Offers the user a choice between revoking a lock from the phone only, or
/// from both the phone and the lock (the latter requires an NFC tap so the
/// `CMD_REVOKE_KEY` command can reach the lock).
///
/// Invoked from the "My Keys" dashboard with [RevokeScope.lockAndPhone]
/// selected; [RevokeScope.phoneOnly] is presented as the no-NFC alternative.
class RevokeLockScreen extends ConsumerStatefulWidget {
  final String lockId;

  const RevokeLockScreen({super.key, required this.lockId});

  @override
  ConsumerState<RevokeLockScreen> createState() => _RevokeLockScreenState();
}

class _RevokeLockScreenState extends ConsumerState<RevokeLockScreen> {
  RevokeScope _scope = RevokeScope.lockAndPhone;
  bool _isRevoking = false;
  String? _errorMessage;
  bool _success = false;

  Future<void> _revoke() async {
    if (_isRevoking) return;

    setState(() {
      _isRevoking = true;
      _errorMessage = null;
    });

    final lockConnection = ref.read(lockConnectionProvider);
    final trustedLocksNotifier = ref.read(trustedLocksNotifierProvider.notifier);

    if (_scope == RevokeScope.phoneOnly) {
      // No NFC required — remove the local trusted entry.
      await trustedLocksNotifier.revokeKey(widget.lockId);
      _finishSuccess();
      return;
    }

    // lockAndPhone: resolve this phone's identity (which the lock holds as an
    // authorized key) and send CMD_REVOKE_KEY over the NFC secure channel.
    final identityKeystore = ref.read(identityKeystoreProvider);
    final phoneIdentity = await identityKeystore.getOrCreateIdentity();
    final result = await lockConnection.revokeKey(
      widget.lockId,
      phoneIdentity.publicKey,
    );

    if (!mounted) return;

    switch (result) {
      case Ok():
        // The lock forgot us. Remove the local entry too.
        await trustedLocksNotifier.revokeKey(widget.lockId);
        _finishSuccess();
      case Err(:final error):
        setState(() {
          _isRevoking = false;
          _errorMessage = error.toString();
        });
    }
  }

  void _finishSuccess() {
    if (!mounted) return;
    setState(() {
      _isRevoking = false;
      _success = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lock removed'),
        backgroundColor: Colors.green,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revoke Lock'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle Light/Dark Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Lock: ${widget.lockId}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _success
                        ? Colors.green.withValues(alpha: 0.12)
                        : (_errorMessage != null
                            ? theme.colorScheme.error.withValues(alpha: 0.12)
                            : theme.colorScheme.primary.withValues(alpha: 0.12)),
                    border: Border.all(
                      color: _success
                          ? Colors.green
                          : (_errorMessage != null
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary),
                      width: 4,
                    ),
                  ),
                  child: Icon(
                    _success
                        ? Icons.check_circle
                        : (_errorMessage != null ? Icons.error_outline : Icons.nfc),
                    size: 80,
                    color: _success
                        ? Colors.green
                        : (_errorMessage != null
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _success
                      ? 'Removed'
                      : (_errorMessage != null
                          ? 'Revoke Failed'
                          : 'Choose how to revoke'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _success
                        ? Colors.green
                        : (_errorMessage != null
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ??
                      (_success
                          ? 'The lock has been removed.'
                          : 'Remove this lock from your phone only, or from the lock itself too.'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _errorMessage != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Revoke scope selection
                _buildScopeOption(
                  context,
                  title: 'Phone only',
                  subtitle: 'Removes the lock from this phone. No NFC needed.',
                  value: RevokeScope.phoneOnly,
                ),
                const SizedBox(height: 12),
                _buildScopeOption(
                  context,
                  title: 'Phone and lock',
                  subtitle:
                      'Also sends CMD_REVOKE_KEY to the lock. Requires an NFC tap.',
                  value: RevokeScope.lockAndPhone,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: _errorMessage != null
                        ? 'Retry'
                        : (_isRevoking
                            ? 'Revoking...'
                            : (_scope == RevokeScope.phoneOnly
                                ? 'Remove from phone'
                                : 'Tap phone to lock to revoke')),
                    isLoading: _isRevoking,
                    onPressed: (_isRevoking || _success) ? null : _revoke,
                  ),
                ),
                if (_isRevoking) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ref.read(lockConnectionProvider).abort();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScopeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required RevokeScope value,
  }) {
    final theme = Theme.of(context);
    final selected = _scope == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _isRevoking
          ? null
          : () => setState(() => _scope = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
