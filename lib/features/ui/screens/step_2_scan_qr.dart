import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/features/session/provisioning/qr_provision_parser.dart';

class Step2ScanQrScreen extends ConsumerStatefulWidget {
  const Step2ScanQrScreen({super.key});

  @override
  ConsumerState<Step2ScanQrScreen> createState() => _Step2ScanQrScreenState();
}

class _Step2ScanQrScreenState extends ConsumerState<Step2ScanQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualInputController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    _processCode(code);
  }

  void _processCode(String code) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final secret = QrProvisionParser.parse(code);

    if (secret != null) {
      // Store the secret in the scoped provider, then move to step 3.
      ref.read(provisionSecretProvider.notifier).set(secret);
      _scannerController.stop();
      Navigator.pushReplacementNamed(
        context,
        '/provision_step_3',
      );
    } else {
      // Show error and resume scanning after delay
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid provision secret. Expected 64 hex characters.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              color: Theme.of(context).colorScheme.surface,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scan the QR code, or manually enter the 64-character provision secret below.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _manualInputController,
                      decoration: const InputDecoration(
                        labelText: 'Manual Secret (Hex)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 64,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () {
                                final text = _manualInputController.text.trim();
                                if (text.isNotEmpty) {
                                  _processCode(text);
                                }
                              },
                        child: const Text('Submit Manual Secret'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
