import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/presentation/screens/circle_list_screen.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_settings_screen.dart';

void main() {
  testWidgets('My Circles settings entry opens the current circle list', (
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

    final target = find.text('My Circles');
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(find.byType(CircleListScreen), findsOneWidget);
    expect(find.byKey(CircleListKeys.title), findsOneWidget);
    expect(find.byKey(CircleListKeys.circle('best-friends')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
