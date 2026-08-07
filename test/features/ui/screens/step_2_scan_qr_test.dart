import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/app/app.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import '../../session/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
  });

  Widget createWidgetToTest() {
    return ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(fakeStorage),
      ],
      child: const App(),
    );
  }

  testWidgets('Step2ScanQrScreen renders manual secret input field', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Navigate to step 1 then step 2
    await tester.tap(find.text('Begin Provisioning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.text('Manual Secret (Hex)'), findsOneWidget);
    expect(find.text('Submit Manual Secret'), findsOneWidget);
  });

  testWidgets('Submitting invalid secret shows snackbar error', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Begin Provisioning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Enter short hex
    await tester.enterText(find.byType(TextField), '123456');
    await tester.ensureVisible(find.text('Submit Manual Secret'));
    await tester.tap(find.text('Submit Manual Secret'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Expected 64 hex characters'), findsOneWidget);

    // Fast-forward pending 2-second debounce timer
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Submitting valid 64-char hex secret advances to step 3', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Begin Provisioning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 64 character valid hex
    const validSecret = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
    await tester.enterText(find.byType(TextField), validSecret);
    await tester.ensureVisible(find.text('Submit Manual Secret'));
    await tester.tap(find.text('Submit Manual Secret'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('NFC Sync'), findsOneWidget);
  });
}
