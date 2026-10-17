import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/presentation/screens/devices_screen.dart';

void main() {
  testWidgets(
    'Devices without account data does not invent registered devices',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: DevicesScreen()));
      expect(find.byKey(DevicesKeys.title), findsOneWidget);
      expect(find.text('Account connection pending'), findsOneWidget);
      expect(find.text('No registered devices'), findsNothing);
      expect(find.byKey(DevicesKeys.register), findsNothing);
    },
  );

  testWidgets('Devices renders known current and remote devices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: DevicesScreen(
          devices: <OrbitRegisteredDevice>[
            OrbitRegisteredDevice(
              id: 'current',
              name: 'My phone',
              platform: 'Android',
              lastSeenLabel: 'Now',
              isCurrent: true,
              isTrusted: true,
            ),
            OrbitRegisteredDevice(
              id: 'other',
              name: 'Tablet',
              platform: 'iOS',
              lastSeenLabel: 'Yesterday',
              isApprovalPending: true,
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(DevicesKeys.row('current')), findsOneWidget);
    expect(find.byKey(DevicesKeys.row('other')), findsOneWidget);
    expect(find.byKey(DevicesKeys.revoke('current')), findsNothing);
    expect(find.byKey(DevicesKeys.revoke('other')), findsOneWidget);
    expect(find.byKey(DevicesKeys.approve('other')), findsOneWidget);
  });

  testWidgets('Remote device removal requires explicit confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var revoked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DevicesScreen(
          devices: const <OrbitRegisteredDevice>[
            OrbitRegisteredDevice(
              id: 'other',
              name: 'Tablet',
              platform: 'iOS',
              lastSeenLabel: 'Yesterday',
            ),
          ],
          onRevokeDevice: (id) async {
            revoked = id == 'other';
          },
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(DevicesKeys.revoke('other')));
    await tester.tap(find.byKey(DevicesKeys.revoke('other')));
    await tester.pumpAndSettle();
    expect(find.text('Remove device?'), findsOneWidget);
    expect(revoked, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(revoked, isFalse);
  });
}
