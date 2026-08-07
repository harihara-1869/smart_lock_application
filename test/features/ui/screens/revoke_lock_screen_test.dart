import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartlock_application/core/nfc_transport/fake_iso_dep_transport.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/features/session/trusted_locks_store.dart';
import 'package:smartlock_application/features/ui/screens/revoke_lock_screen.dart';

import '../../session/fake_flutter_secure_storage.dart';

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late FakeIsoDepTransport fakeTransport;
  late TrustedLocksStore trustedStore;

  setUp(() async {
    fakeStorage = FakeFlutterSecureStorage();
    fakeTransport = FakeIsoDepTransport();
    trustedStore = TrustedLocksStore(storage: fakeStorage);
    await trustedStore.storeTrustedKey(
      'Lock-XYZ',
      Uint8List.fromList(List.filled(32, 0x01)),
    );
  });

  Widget createWidgetToTest({String lockId = 'Lock-XYZ'}) {
    return ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(fakeStorage),
        isoDepTransportProvider.overrideWithValue(fakeTransport),
        trustedLocksStoreProvider.overrideWithValue(trustedStore),
      ],
      child: MaterialApp(home: RevokeLockScreen(lockId: lockId)),
    );
  }

  testWidgets('RevokeLockScreen renders title and scope choices', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Revoke Lock'), findsOneWidget);
    expect(find.text('Lock: Lock-XYZ'), findsOneWidget);
    expect(find.text('Phone only'), findsOneWidget);
    expect(find.text('Phone and lock'), findsOneWidget);
    expect(find.text('Tap phone to lock to revoke'), findsOneWidget);
  });

  testWidgets(
    'Selecting Phone only updates button label and removes local key',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetToTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap "Phone only" option
      await tester.tap(find.text('Phone only'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Remove from phone'), findsOneWidget);

      // Tap "Remove from phone" button
      await tester.ensureVisible(find.text('Remove from phone'));
      await tester.tap(find.text('Remove from phone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Removed'), findsOneWidget);
      final remainingLocks = await trustedStore.listTrustedLocks();
      expect(remainingLocks, isEmpty);

      // Fast-forward 2-second navigation timer
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'Selecting Phone and lock triggers NFC session and loading state',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetToTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap "Tap phone to lock to revoke" button (Phone and lock is default)
      await tester.ensureVisible(find.text('Tap phone to lock to revoke'));
      await tester.tap(find.text('Tap phone to lock to revoke'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Fast-forward 30s tag wait timeout
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets('Tapping Cancel aborts NFC revocation session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetToTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.ensureVisible(find.text('Tap phone to lock to revoke'));
    await tester.tap(find.text('Tap phone to lock to revoke'));
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    // Fast-forward 30s tag wait timeout
    await tester.pump(const Duration(seconds: 30));
  });
}
