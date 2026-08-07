import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartlock_application/app/theme.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/features/ui/screens/my_keys_screen.dart';
import 'package:smartlock_application/features/ui/screens/step_1_press_button.dart';
import 'package:smartlock_application/features/ui/screens/step_2_scan_qr.dart';
import 'package:smartlock_application/features/ui/screens/step_3_nfc_sync.dart';
import 'package:smartlock_application/features/ui/screens/actuate_lock_screen.dart';
import 'package:smartlock_application/features/ui/screens/revoke_lock_screen.dart';

/// Root widget for the NFC Smart Lock application.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'NFC Smart Lock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const MyKeysScreen(),
              settings: settings,
            );
          case '/provision_step_1':
            return MaterialPageRoute(
              builder: (_) => const Step1PressButtonScreen(),
              settings: settings,
            );
          case '/provision_step_2':
            return MaterialPageRoute(
              builder: (_) => const Step2ScanQrScreen(),
              settings: settings,
            );
          case '/provision_step_3':
            // The provision secret is read from `provisionSecretProvider`,
            // not from route arguments.
            return MaterialPageRoute(
              builder: (_) => const Step3NfcSyncScreen(),
              settings: settings,
            );
          case '/actuate':
            final lockId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => ActuateLockScreen(lockId: lockId),
              settings: settings,
            );
          case '/revoke_lock':
            final lockId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => RevokeLockScreen(lockId: lockId),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text('No route defined for ${settings.name}')),
              ),
              settings: settings,
            );
        }
      },
    );
  }
}
