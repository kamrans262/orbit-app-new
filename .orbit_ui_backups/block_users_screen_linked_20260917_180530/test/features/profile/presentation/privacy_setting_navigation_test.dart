import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/blocked_users_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/privacy_setting_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = ProfileData(
    id: 'emma',
    name: 'Emma ⭐',
    bio: 'Good vibes only',
    imagePath: 'assets/Emma.png',
    circleCount: 10,
    friendCount: 24,
    momentCount: 120,
    moments: <ProfileMomentData>[],
  );

  testWidgets('Settings Privacy Settings row opens PrivacySettingScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          profile: profile,
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final privacyRow = find.byKey(SettingsKeys.item('privacy'));
    await tester.ensureVisible(privacyRow);
    await tester.pumpAndSettle();
    expect(privacyRow.hitTestable(), findsOneWidget);

    await tester.tap(privacyRow.hitTestable());
    await tester.pumpAndSettle();

    expect(find.byType(PrivacySettingScreen), findsOneWidget);
    expect(find.text('Who can see location'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings Blocked Users row opens BlockedUsersScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          profile: profile,
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final blockedRow = find.byKey(SettingsKeys.item('blocked'));
    await tester.ensureVisible(blockedRow);
    await tester.pumpAndSettle();
    expect(blockedRow.hitTestable(), findsOneWidget);

    await tester.tap(blockedRow.hitTestable());
    await tester.pumpAndSettle();

    expect(find.byType(BlockedUsersScreen), findsOneWidget);
    expect(find.text('No blocked users'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
