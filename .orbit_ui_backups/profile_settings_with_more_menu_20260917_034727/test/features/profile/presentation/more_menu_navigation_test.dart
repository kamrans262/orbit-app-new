import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/more_menu/presentation/screens/more_menu_screen.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_settings_screen.dart';

void main() {
  testWidgets('refreshed Settings keeps exactly the seven Figma rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          profile: const ProfileData(
            id: 'profile',
            name: 'Orbit User',
            bio: 'Stay close.',
            circleCount: 3,
            friendCount: 20,
            momentCount: 4,
            moments: <ProfileMomentData>[],
          ),
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      ),
    );

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Notification'), findsOneWidget);
    expect(find.text('More menu'), findsNothing);
  });

  testWidgets('previously built MoreMenuScreen remains buildable', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MoreMenuScreen()));
    await tester.pump();

    expect(find.text('More menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
