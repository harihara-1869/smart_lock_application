import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartlock_application/core/result.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/core/widgets/primary_button.dart';

class Step3NfcSyncScreen extends ConsumerStatefulWidget {
  const Step3NfcSyncScreen({super.key});

  @override
  ConsumerState<Step3NfcSyncScreen> createState() => _Step3NfcSyncScreenState();
}

class _Step3NfcSyncScreenState extends ConsumerState<Step3NfcSyncScreen> {
  bool _isProvisioning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-start provisioning when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProvisioning();
    });
  }

  Future<void> _startProvisioning() async {
    if (_isProvisioning) return;

    final provisionSecret = ref.read(provisionSecretProvider);
    if (provisionSecret == null) {
      setState(() {
        _errorMessage = 'Missing provision secret — rescan the QR code.';
      });
      return;
    }

    setState(() {
      _isProvisioning = true;
      _errorMessage = null;
    });

    final provisionController = ref.read(provisionControllerProvider);
    final lockId = "Lock-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
    final result = await provisionController.provisionLock(
      lockId: lockId,
      provisionSecret: provisionSecret,
    );

    if (mounted) {
      switch (result) {
        case Ok():
          // Success! Clear the one-shot secret and refresh the keys list.
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          ref.read(provisionSecretProvider.notifier).clear();
          ref.read(trustedLocksNotifierProvider.notifier).refresh();
          navigator.popUntil((route) => route.isFirst || route.settings.name == '/');
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Lock successfully provisioned!'),
              backgroundColor: Colors.green,
            ),
          );
        case Err(:final error):
          setState(() {
            _isProvisioning = false;
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
        title: const Text('NFC Sync'),
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
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _errorMessage != null
                      ? theme.colorScheme.error.withValues(alpha: 0.12)
                      : theme.colorScheme.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _errorMessage != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    width: 4,
                  ),
                ),
                child: Icon(
                  _errorMessage != null ? Icons.error_outline : Icons.nfc,
                  size: 80,
                  color: _errorMessage != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _errorMessage != null ? 'Sync Failed' : 'Ready to Sync',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _errorMessage != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ??
                    'Place the top of your phone securely against the lock\'s NFC pad and hold it steady.',
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
                  text: _errorMessage != null ? 'Retry Sync' : (_isProvisioning ? 'Syncing...' : 'Start'),
                  isLoading: _isProvisioning,
                  onPressed: _isProvisioning ? null : _startProvisioning,
                ),
              ),
              if (_isProvisioning) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    ref.read(provisionControllerProvider).abort();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
