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

  testWidgets('Step1PressButtonScreen renders title and instructions', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Navigate from MyKeysScreen to Step 1
    await tester.tap(find.text('Begin Provisioning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Provision Lock'), findsOneWidget);
    expect(find.text('Put the Lock in provision mode'), findsOneWidget);
    expect(find.textContaining('Press the physical button'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Tapping Next navigates to Scan QR screen', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Begin Provisioning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Scan QR Code'), findsOneWidget);
  });
}
