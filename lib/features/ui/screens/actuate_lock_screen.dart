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

  Future<void> _actuateLock() async {
    if (_isActuating) return;

    setState(() {
      _isActuating = true;
      _errorMessage = null;
      _success = false;
    });

    final lockConnection = ref.read(lockConnectionProvider);
    final result = await lockConnection.unlock(widget.lockId);

    if (mounted) {
      switch (result) {
        case Ok():
          setState(() {
            _isActuating = false;
            _success = true;
          });
          // Show success snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lock Unlocked Successfully!'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                      ? Colors.green.withValues(alpha: 0.1)
                      : (_errorMessage != null
                          ? theme.colorScheme.error.withValues(alpha: 0.1)
                          : theme.colorScheme.primaryContainer),
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
                      ? Icons.lock_open
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
                    ? 'Unlocked!'
                    : (_errorMessage != null
                        ? 'Unlock Failed'
                        : 'Ready to Unlock'),
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
                        ? 'You may now open the door.'
                        : 'Place phone near the lock\'s NFC pad to actuate.'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _errorMessage != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: _errorMessage != null
                      ? 'Retry'
                      : (_isActuating ? 'Actuating...' : 'Tap to Unlock'),
                  isLoading: _isActuating,
                  onPressed: (_isActuating || _success) ? null : _actuateLock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
