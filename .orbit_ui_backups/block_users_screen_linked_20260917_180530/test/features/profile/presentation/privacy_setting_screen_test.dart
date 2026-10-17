import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_action_row.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/circle_setting_toggle.dart';
import 'package:orbit_ui/features/profile/domain/models/privacy_settings.dart';
import 'package:orbit_ui/features/profile/presentation/screens/blocked_users_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/privacy_setting_screen.dart';
import 'package:orbit_ui/features/profile/presentation/widgets/orbit_dropdown_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Privacy Setting renders Figma controls and demo values', (
    tester,
  ) async {
    await _pumpPrivacy(tester);

    expect(find.text('Privacy Setting'), findsOneWidget);
    expect(find.text('Who can see location'), findsOneWidget);
    expect(find.text('My Circle'), findsWidgets);
    expect(find.text('Location Activity'), findsOneWidget);
    expect(find.text('abcfg..'), findsWidgets);
    expect(find.text('Location Sharing'), findsOneWidget);
    expect(find.text('Ghost mode'), findsOneWidget);
    expect(find.text('Block User'), findsOneWidget);

    expect(find.byType(OrbitDropdownField), findsNWidgets(2));
    expect(find.byType(AppActionRow), findsNWidgets(3));
    expect(OrbitDropdownField.referenceHeight, 51);
    expect(OrbitDropdownField.radius, 30);
    expect(AppActionRow.referenceHeight, 68);
    expect(AppActionRow.radius, 30);

    expect(
      _toggle(tester, PrivacySettingKeys.locationSharingToggle).value,
      isTrue,
    );
    expect(_toggle(tester, PrivacySettingKeys.ghostModeToggle).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Privacy state updates independently', (tester) async {
    final changes = <PrivacySettings>[];
    await _pumpPrivacy(tester, onSettingsChanged: changes.add);

    await tester.tap(find.byKey(PrivacySettingKeys.ghostModeRow));
    await tester.pump();

    expect(_toggle(tester, PrivacySettingKeys.ghostModeToggle).value, isFalse);
    expect(
      _toggle(tester, PrivacySettingKeys.locationSharingToggle).value,
      isTrue,
    );
    expect(changes, hasLength(1));
    expect(changes.single.ghostModeEnabled, isFalse);
    expect(changes.single.locationSharingEnabled, isTrue);

    final visibility = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>).first,
    );
    visibility.onChanged?.call('Friends');
    await tester.pump();

    expect(changes.last.locationVisibility, 'Friends');
    expect(changes.last.ghostModeEnabled, isFalse);
  });

  testWidgets('Block User opens BlockedUsersScreen', (tester) async {
    await _pumpPrivacy(tester);

    await tester.tap(find.byKey(PrivacySettingKeys.blockUserRow));
    await tester.pumpAndSettle();

    expect(find.byType(BlockedUsersScreen), findsOneWidget);
    expect(find.text('Blocked Users'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Privacy Setting remains scroll-safe at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await _pumpPrivacy(tester, configureView: false);
        expect(find.byKey(PrivacySettingKeys.scrollView), findsOneWidget);

        await tester.drag(
          find.byKey(PrivacySettingKeys.scrollView),
          const Offset(0, -240),
        );
        await tester.pumpAndSettle();

        expect(find.text('Block User'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

CircleSettingToggle _toggle(WidgetTester tester, Key key) {
  return tester.widget<CircleSettingToggle>(find.byKey(key));
}

Future<void> _pumpPrivacy(
  WidgetTester tester, {
  ValueChanged<PrivacySettings>? onSettingsChanged,
  bool configureView = true,
}) async {
  if (configureView) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  await tester.pumpWidget(
    MaterialApp(
      home: PrivacySettingScreen(onSettingsChanged: onSettingsChanged),
    ),
  );
  await tester.pump();
}
