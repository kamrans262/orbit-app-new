import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/more_menu/presentation/screens/more_menu_screen.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_settings_screen.dart';

void main() {
  testWidgets('Profile Settings More menu entry opens MoreMenuScreen', (
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

    final entry = find.byKey(SettingsKeys.item('more_menu'));
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    expect(entry.hitTestable(), findsOneWidget);
    await tester.tap(entry.hitTestable());
    await tester.pumpAndSettle();

    expect(find.byType(MoreMenuScreen), findsOneWidget);
    expect(find.text('Orbit Menu'), findsOneWidget);
  });
}
