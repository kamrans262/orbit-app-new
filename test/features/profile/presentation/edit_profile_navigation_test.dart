import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_settings_screen.dart';

void main() {
  testWidgets('Settings Edit Profile entry opens EditProfileScreen', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          profile: profile,
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Change Photo'), findsOneWidget);
    final fullNameField = find.descendant(
      of: find.byKey(EditProfileKeys.fullNameField),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(fullNameField).controller?.text,
      'Emma Shan',
    );
    expect(tester.takeException(), isNull);
  });
}
