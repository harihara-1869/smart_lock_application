import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/app/app.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/features/session/trusted_locks_store.dart';

import '../../session/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late TrustedLocksStore trustedStore;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    trustedStore = TrustedLocksStore(storage: fakeStorage);
  });

  Widget createWidgetToTest() {
    return ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(fakeStorage),
        trustedLocksStoreProvider.overrideWithValue(trustedStore),
      ],
      child: const App(),
    );
  }

  testWidgets('MyKeysScreen shows empty state when no locks stored', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('My Keys'), findsOneWidget);
    expect(find.textContaining('No active keys found'), findsOneWidget);
    expect(find.text('Begin Provisioning'), findsOneWidget);
  });

  testWidgets('MyKeysScreen lists stored locks', (WidgetTester tester) async {
    await trustedStore.storeTrustedKey('Lock-1234', Uint8List.fromList(List.filled(32, 0x01)));

    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Lock: Lock-1234'), findsOneWidget);
    expect(find.text('Stored securely'), findsOneWidget);
  });

  testWidgets('Begin Provisioning button navigates to step 1', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Begin Provisioning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Put the Lock in provision mode'), findsOneWidget);
  });

  testWidgets('Tapping delete icon shows Revoke Key dialog', (WidgetTester tester) async {
    await trustedStore.storeTrustedKey('Lock-1234', Uint8List.fromList(List.filled(32, 0x01)));

    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Revoke Key?'), findsOneWidget);
    expect(find.text('Phone only'), findsOneWidget);
    expect(find.text('Phone & lock'), findsOneWidget);
  });
}
