import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/nfc_transport/fake_iso_dep_transport.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/features/session/trusted_locks_store.dart';
import 'package:smartlock_application/features/ui/screens/actuate_lock_screen.dart';

import '../../session/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late FakeIsoDepTransport fakeTransport;
  late TrustedLocksStore trustedStore;

  setUp(() async {
    fakeStorage = FakeFlutterSecureStorage();
    fakeTransport = FakeIsoDepTransport();
    trustedStore = TrustedLocksStore(storage: fakeStorage);
    await trustedStore.storeTrustedKey('Lock-ABC', Uint8List.fromList(List.filled(32, 0x01)));
  });

  Widget createWidgetToTest({String lockId = 'Lock-ABC'}) {
    return ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(fakeStorage),
        isoDepTransportProvider.overrideWithValue(fakeTransport),
        trustedLocksStoreProvider.overrideWithValue(trustedStore),
      ],
      child: MaterialApp(
        home: ActuateLockScreen(lockId: lockId),
      ),
    );
  }

  testWidgets('ActuateLockScreen renders title and dual action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Actuate Lock'), findsOneWidget);
    expect(find.text('Lock: Lock-ABC'), findsOneWidget);
    expect(find.text('Lock / Unlock Control'), findsOneWidget);
    expect(find.text('Tap to Unlock'), findsOneWidget);
    expect(find.text('Tap to Lock'), findsOneWidget);
  });

  testWidgets('Tapping unlock button sets loading state', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Tap to Unlock'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Fast forward 30s tag wait timeout
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Tapping lock button sets loading state', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Tap to Lock'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Fast forward 30s tag wait timeout
    await tester.pump(const Duration(seconds: 30));
  });
}
