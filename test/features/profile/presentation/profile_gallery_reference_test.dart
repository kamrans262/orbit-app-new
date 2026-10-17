import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Profile demo uses reference masonry proportions without top cropping',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final screen = ProfileScreen.demo();
      expect(screen.profile.moments[0].imagePath, 'assets/gallery1.jpg');
      expect(screen.profile.moments[0].aspectRatio, 0.86);
      expect(screen.profile.moments[1].imagePath, 'assets/gallery4.jpg');
      expect(screen.profile.moments[2].imagePath, 'assets/gallery2.jpg');
      expect(screen.profile.moments[2].remainingCount, 202);
      expect(screen.profile.moments[3].imagePath, 'assets/gallery3.jpg');

      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump();
      // The current default tab is Overview. Full-size masonry is rendered
      // under Moments, while Overview intentionally uses smaller previews.
      await tester.tap(find.byKey(ProfileKeys.momentsTab));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileKeys.gallery), findsOneWidget);

      final firstTile = tester.getSize(
        find.byKey(ProfileKeys.moment('gallery-1')),
      );
      expect(firstTile.height, greaterThan(firstTile.width));
      expect(firstTile.width / firstTile.height, closeTo(0.86, 0.02));

      final gradientRect = tester.getRect(
        find.byKey(ProfileKeys.gradientBackground),
      );
      final firstTileRect = tester.getRect(
        find.byKey(ProfileKeys.moment('gallery-1')),
      );
      expect(firstTileRect.top, lessThan(gradientRect.bottom));
      expect(tester.takeException(), isNull);
    },
  );
}
