import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/popups/orbit_popup_modal.dart';
import 'package:orbit_ui/core/widgets/app_text_field.dart';
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

  testWidgets('Rename device uses approved Orbit popup, field and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final renamed = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: DevicesScreen(
        devices: const <OrbitRegisteredDevice>[
          OrbitRegisteredDevice(
            id: 'current',
            name: 'My phone',
            platform: 'Android',
            lastSeenLabel: 'Now',
            isCurrent: true,
            isTrusted: true,
          ),
        ],
        onRenameDevice: (id, name) async {
          renamed.add('$id:$name');
        },
      ),
    ));

    await tester.tap(find.byKey(DevicesKeys.rename('current')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orbit_popup_card')), findsOneWidget);
    expect(find.byKey(DevicesKeys.renameField), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byType(OrbitPopupPrimaryButton), findsOneWidget);
    expect(find.byType(OrbitPopupTextButton), findsOneWidget);
    expect(find.text('Rename device'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'My phone',
    );

    await tester.enterText(find.byType(TextField), '  ');
    await tester.pumpAndSettle();
    expect(
      tester.widget<OrbitPopupPrimaryButton>(
        find.byType(OrbitPopupPrimaryButton),
      ).enabled,
      isFalse,
    );
    expect(renamed, isEmpty);

    await tester.enterText(find.byType(TextField), 'My tablet');
    await tester.pumpAndSettle();
    expect(
      tester.widget<OrbitPopupPrimaryButton>(
        find.byType(OrbitPopupPrimaryButton),
      ).enabled,
      isTrue,
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(renamed, <String>['current:My tablet']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rename Cancel does not submit an update', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: DevicesScreen(
        devices: const <OrbitRegisteredDevice>[
          OrbitRegisteredDevice(
            id: 'current',
            name: 'My phone',
            platform: 'Android',
            lastSeenLabel: 'Now',
          ),
        ],
        onRenameDevice: (id, name) async {
          saves++;
        },
      ),
    ));

    await tester.tap(find.byKey(DevicesKeys.rename('current')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Changed');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(tester.takeException(), isNull);
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
    expect(find.byType(OrbitPopupModal), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(revoked, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(revoked, isFalse);
  });
}
