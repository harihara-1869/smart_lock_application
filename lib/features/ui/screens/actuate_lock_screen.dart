import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/core/widgets/primary_button.dart';

class ActuateLockScreen extends ConsumerStatefulWidget {
  final String lockId;

  const ActuateLockScreen({
    super.key,
    required this.lockId,
  });

  @override
  ConsumerState<ActuateLockScreen> createState() => _ActuateLockScreenState();
}

class _ActuateLockScreenState extends ConsumerState<ActuateLockScreen> {
  bool _isActuating = false;
  String? _errorMessage;
  bool _success = false;
  bool _lastWasLock = false;

  Future<void> _actuateLock({required bool isLocking}) async {
    if (_isActuating) return;

    setState(() {
      _isActuating = true;
      _errorMessage = null;
      _success = false;
      _lastWasLock = isLocking;
    });

    final lockConnection = ref.read(lockConnectionProvider);
    final result = isLocking
        ? await lockConnection.lock(widget.lockId)
        : await lockConnection.unlock(widget.lockId);

    if (mounted) {
      switch (result) {
        case Ok():
          setState(() {
            _isActuating = false;
            _success = true;
          });
          final actionText = isLocking ? 'Locked' : 'Unlocked';
          // Show success snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lock $actionText Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Go back after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        case Err(:final error):
          setState(() {
            _isActuating = false;
            _errorMessage = error.toString();
          });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String headlineText = _success
        ? (_lastWasLock ? 'Locked!' : 'Unlocked!')
        : (_errorMessage != null
            ? (_lastWasLock ? 'Lock Failed' : 'Unlock Failed')
            : 'Lock / Unlock Control');

    final String bodyText = _errorMessage ??
        (_success
            ? (_lastWasLock ? 'The door is now locked.' : 'You may now open the door.')
            : 'Place phone near the lock\'s NFC pad to actuate.');

    final IconData statusIcon = _success
        ? (_lastWasLock ? Icons.lock : Icons.lock_open)
        : (_errorMessage != null ? Icons.error_outline : Icons.nfc);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actuate Lock'),
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
              const Spacer(),
              // Central NFC Actuation visualization
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
                  statusIcon,
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
                headlineText,
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
                bodyText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _errorMessage != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_errorMessage != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Retry',
                    onPressed: () => _actuateLock(isLocking: _lastWasLock),
                  ),
                ),
              ] else if (_isActuating) ...[
                const SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Actuating...',
                    isLoading: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    ref.read(lockConnectionProvider).abort();
                  },
                  child: const Text('Cancel'),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Tap to Unlock',
                    icon: Icons.lock_open,
                    onPressed: _success ? null : () => _actuateLock(isLocking: false),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Tap to Lock',
                    icon: Icons.lock,
                    onPressed: _success ? null : () => _actuateLock(isLocking: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
