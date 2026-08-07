import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/nfc_transport/fake_iso_dep_transport.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/features/ui/screens/step_3_nfc_sync.dart';

import '../../session/fake_flutter_secure_storage.dart';

class InitialSecretNotifier extends ProvisionSecretNotifier {
  final Uint8List? _initialSecret;
  InitialSecretNotifier(this._initialSecret);

  @override
  Uint8List? build() => _initialSecret;
}

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late FakeIsoDepTransport fakeTransport;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    fakeTransport = FakeIsoDepTransport();
  });

  Widget createWidgetToTest({Uint8List? secret}) {
    return ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(fakeStorage),
        isoDepTransportProvider.overrideWithValue(fakeTransport),
        provisionSecretProvider.overrideWith(() => InitialSecretNotifier(secret)),
      ],
      child: const MaterialApp(
        home: Step3NfcSyncScreen(),
      ),
    );
  }

  testWidgets('Step3NfcSyncScreen shows missing secret error when secret is null', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetToTest(secret: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('NFC Sync'), findsOneWidget);
    expect(find.textContaining('Missing provision secret'), findsOneWidget);
  });

  testWidgets('Step3NfcSyncScreen renders ready state when secret exists', (WidgetTester tester) async {
    final secret = Uint8List(32);
    await tester.pumpWidget(createWidgetToTest(secret: secret));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('NFC Sync'), findsOneWidget);
    expect(find.byIcon(Icons.nfc), findsOneWidget);

    // Fast-forward the 30-second tag-wait timeout timer to clean up
    await tester.pump(const Duration(seconds: 30));
  });
}
