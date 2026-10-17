import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/notification_screen.dart';
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

  testWidgets('Settings Notification row opens NotificationScreen', (
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

    final notificationRow = find.byKey(SettingsKeys.item('notification'));
    await tester.ensureVisible(notificationRow);
    await tester.pumpAndSettle();

    expect(notificationRow.hitTestable(), findsOneWidget);
    await tester.tap(notificationRow.hitTestable());
    await tester.pumpAndSettle();

    expect(find.byType(NotificationScreen), findsOneWidget);
    expect(find.text('Push Notification'), findsOneWidget);
    expect(find.text('Sound'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
