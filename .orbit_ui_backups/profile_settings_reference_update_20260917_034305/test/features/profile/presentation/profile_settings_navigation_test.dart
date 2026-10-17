import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_settings_screen.dart';

void main() {
  testWidgets('Profile settings button opens refreshed shared Settings screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen.demo(
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(ProfileKeys.settingsButton));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Emma ⭐'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Notification'), findsOneWidget);
    expect(find.text('Location Settings'), findsNothing);
    expect(find.byKey(SettingsKeys.bottomNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
