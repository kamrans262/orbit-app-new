import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_screen.dart';

void main() {
  testWidgets(
    'Home Profile tab opens Profile and Home returns without 800x600 assumptions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
      await tester.pumpAndSettle();

      final profileTab = find.text('Profile');
      expect(profileTab, findsOneWidget);
      expect(profileTab.hitTestable(), findsOneWidget);
      await tester.tap(profileTab.hitTestable());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Emma ⭐'), findsOneWidget);

      final homeTab = find.text('Home');
      expect(homeTab.hitTestable(), findsOneWidget);
      await tester.tap(homeTab.hitTestable());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
