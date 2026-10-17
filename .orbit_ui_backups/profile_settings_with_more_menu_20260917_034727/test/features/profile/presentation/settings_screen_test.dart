import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:orbit_ui/features/profile/presentation/widgets/settings_list_item.dart';

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

  testWidgets('Settings matches the refreshed seven-row Profile Figma', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      SettingsScreen(
        profile: profile,
        onTabSelected: (_) {},
        onAddPressed: () {},
      ),
    );

    expect(find.text('Emma ⭐'), findsOneWidget);
    expect(find.text('Good vibes only'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);

    for (final label in <String>[
      'Edit Profile',
      'My Circles',
      'Friends',
      'Notification',
      'Blocked Users',
      'Privacy Settings',
      'SOS Settings',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(find.text('Location Settings'), findsNothing);
    expect(find.text('More menu'), findsNothing);
    expect(find.byType(SettingsListItem), findsNWidgets(7));
    expect(find.byKey(SettingsKeys.listCard), findsOneWidget);
    expect(find.byKey(SettingsKeys.bottomNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings rows use the Figma 42px icon rhythm and callbacks', (
    tester,
  ) async {
    final calls = <String>[];

    await _pumpSettings(
      tester,
      SettingsScreen(
        profile: profile,
        onTabSelected: (_) {},
        onAddPressed: () {},
        onEditProfilePressed: () => calls.add('edit'),
        onMyCirclesPressed: () => calls.add('circles'),
        onFriendsPressed: () => calls.add('friends'),
        onNotificationPressed: () => calls.add('notification'),
        onBlockedUsersPressed: () => calls.add('blocked'),
        onPrivacySettingsPressed: () => calls.add('privacy'),
        onSosSettingsPressed: () => calls.add('sos'),
      ),
    );

    const expected = <MapEntry<String, String>>[
      MapEntry('edit_profile', 'edit'),
      MapEntry('circles', 'circles'),
      MapEntry('friends', 'friends'),
      MapEntry('notification', 'notification'),
      MapEntry('blocked', 'blocked'),
      MapEntry('privacy', 'privacy'),
      MapEntry('sos', 'sos'),
    ];

    for (final entry in expected) {
      final item = tester.widget<SettingsListItem>(
        find.byKey(SettingsKeys.item(entry.key)),
      );
      item.onTap();
    }

    expect(calls, <String>[
      'edit',
      'circles',
      'friends',
      'notification',
      'blocked',
      'privacy',
      'sos',
    ]);
    expect(SettingsListItem.iconCircleSize, 42);
    expect(SettingsListItem.iconToLabelGap, 17);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 866),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Settings remains overflow-safe at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await _pumpSettings(
          tester,
          SettingsScreen(
            profile: const ProfileData(
              id: 'long-profile',
              name: 'A very long backend profile name that stays layout safe',
              bio: 'A longer backend biography that may wrap naturally without overflowing the settings header.',
              circleCount: 999,
              friendCount: 12000,
              momentCount: 500000,
              moments: <ProfileMomentData>[],
            ),
            onTabSelected: (_) {},
            onAddPressed: () {},
          ),
        );

        await tester.drag(
          find.byKey(SettingsKeys.scrollView),
          const Offset(0, -260),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpSettings(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}
