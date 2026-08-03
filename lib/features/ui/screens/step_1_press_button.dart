import 'package:flutter/material.dart';
import 'package:smartlock_application/core/widgets/primary_button.dart';

class Step1PressButtonScreen extends StatelessWidget {
  const Step1PressButtonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provision Lock'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(Icons.touch_app, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 32),
              Text(
                'Put the Lock in provision mode',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Press the physical button on your Smart Lock to put it into provision mode.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Next',
                  onPressed: () {
                    Navigator.pushNamed(context, '/provision_step_2');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
