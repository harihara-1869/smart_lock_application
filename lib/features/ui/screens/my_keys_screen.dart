import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/core/widgets/primary_button.dart';
import 'package:smartlock_application/core/widgets/secure_card.dart';
import 'package:smartlock_application/features/ui/screens/revoke_lock_screen.dart';

class MyKeysScreen extends ConsumerWidget {
  const MyKeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustedLocksAsync = ref.watch(trustedLocksNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Keys'),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Light/Dark Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
      body: trustedLocksAsync.when(
        data: (locks) {
          if (locks.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.separated(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
            itemCount: locks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final lockId = locks[index];
              return _buildLockCard(context, ref, lockId, isDark);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            text: 'Begin Provisioning',
            icon: Icons.add_circle,
            onPressed: () {
              // Navigate to provisioning flow (Phase 13)
              Navigator.pushNamed(context, '/provision_step_1');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLockCard(BuildContext context, WidgetRef ref, String lockId, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariantColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final errorColor = Theme.of(context).colorScheme.error;
    
    // In Flutter 3.22+, you can access surfaceContainerHighest if properly themed.
    // We'll use surfaceContainerHighest or surfaceVariant as fallback.
    final iconBgColor = Theme.of(context).colorScheme.surfaceContainerHighest; 

    return SecureCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        // Navigate to Actuate screen (Phase 14)
        Navigator.pushNamed(context, '/actuate', arguments: lockId);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBgColor,
                ),
                child: Icon(
                  Icons.door_front_door,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lock: $lockId', 
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onSurfaceColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Stored securely',
                        style: TextStyle(
                          fontSize: 12,
                          color: onSurfaceVariantColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.delete, color: onSurfaceVariantColor),
            hoverColor: errorColor.withValues(alpha: 0.1),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scope = await _showRevokeDialog(context);
              switch (scope) {
                case RevokeScope.phoneOnly:
                  ref.read(trustedLocksNotifierProvider.notifier).revokeKey(lockId);
                case RevokeScope.lockAndPhone:
                  navigator.pushNamed('/revoke_lock', arguments: lockId);
                case null:
                  break; // dismissed
              }
            },
          ),
        ],
      ),
    );
  }

  /// Asks the user whether to revoke from the phone only, or from the lock too.
  ///
  /// Returns `null` if dismissed, or the chosen [RevokeScope].
  Future<RevokeScope?> _showRevokeDialog(BuildContext context) {
    return showDialog<RevokeScope>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Revoke Key?'),
          content: const Text('Choose how you want to revoke this lock.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, RevokeScope.phoneOnly),
              child: const Text('Phone only'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, RevokeScope.lockAndPhone),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Phone & lock'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final onSurfaceVariantColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key_off, size: 48, color: onSurfaceVariantColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No active keys found.\nProvision a new device to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: onSurfaceVariantColor,
            ),
          ),
        ],
      ),
    );
  }
}
