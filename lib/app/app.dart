import 'package:flutter/material.dart';
import 'package:smartlock_application/app/theme.dart';

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
      home: const Scaffold(body: Center(child: Text('NFC Smart Lock'))),
    );
  }
}
