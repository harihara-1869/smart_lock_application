import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:smartlock_application/app/theme.dart';
import 'package:smartlock_application/features/ui/screens/my_keys_screen.dart';
import 'package:smartlock_application/features/ui/screens/step_1_press_button.dart';
import 'package:smartlock_application/features/ui/screens/step_2_scan_qr.dart';
import 'package:smartlock_application/features/ui/screens/step_3_nfc_sync.dart';
import 'package:smartlock_application/features/ui/screens/actuate_lock_screen.dart';

/// Root widget for the NFC Smart Lock application.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC Smart Lock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const MyKeysScreen());
          case '/provision_step_1':
            return MaterialPageRoute(builder: (_) => const Step1PressButtonScreen());
          case '/provision_step_2':
            return MaterialPageRoute(builder: (_) => const Step2ScanQrScreen());
          case '/provision_step_3':
            final secret = settings.arguments as Uint8List;
            return MaterialPageRoute(
              builder: (_) => Step3NfcSyncScreen(provisionSecret: secret),
            );
          case '/actuate':
            final lockId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => ActuateLockScreen(lockId: lockId),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text('No route defined for ${settings.name}')),
              ),
            );
        }
      },
    );
  }
}
