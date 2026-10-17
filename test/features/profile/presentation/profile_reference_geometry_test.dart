import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Profile uses a half-viewport gradient and overlaps gallery without translating tiles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(home: ProfileScreen.demo()));
      await tester.pump();

      final scrollRect = tester.getRect(find.byKey(ProfileKeys.scrollView));
      final gradientRect = tester.getRect(
        find.byKey(ProfileKeys.gradientBackground),
      );
      final firstMomentRect = tester.getRect(
        find.byKey(ProfileKeys.moment('gallery-1')),
      );

      expect(gradientRect.top, 0);
      expect(
        (gradientRect.height - (scrollRect.height * 0.5)).abs(),
        lessThan(1.0),
      );
      expect(firstMomentRect.top, lessThan(gradientRect.bottom));
      expect(gradientRect.bottom - firstMomentRect.top, closeTo(52, 1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Profile reference layout is overflow-safe at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(MaterialApp(home: ProfileScreen.demo()));
        await tester.pump();

        await tester.drag(
          find.byKey(ProfileKeys.scrollView),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
