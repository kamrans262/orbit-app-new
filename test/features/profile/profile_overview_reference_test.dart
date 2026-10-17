import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_screen.dart';

void main() {
  testWidgets(
    'Profile Overview uses the current tabs and existing navigation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(home: ProfileScreen.demo()));
      await tester.pumpAndSettle();

      expect(find.byKey(ProfileKeys.avatar), findsOneWidget);
      expect(find.byKey(ProfileKeys.settingsButton), findsOneWidget);
      expect(find.byKey(ProfileKeys.bottomNavigation), findsOneWidget);
      expect(find.byKey(ProfileKeys.overviewTab), findsOneWidget);
      expect(find.text('My Orbit'), findsOneWidget);

      await tester.tap(find.byKey(ProfileKeys.placesTab));
      await tester.pumpAndSettle();
      expect(find.text('Recently Been'), findsOneWidget);
      expect(find.text('Highlights'), findsNothing);

      await tester.tap(find.byKey(ProfileKeys.momentsTab));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileKeys.gallery), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
