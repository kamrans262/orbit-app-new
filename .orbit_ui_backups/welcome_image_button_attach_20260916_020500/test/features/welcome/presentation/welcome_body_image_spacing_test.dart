import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/widgets/welcome_illustration.dart';

void main() {
  Widget buildScreen() {
    return MaterialApp(
      home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Welcome body and image stay naturally connected at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final bodyRect = tester.getRect(find.byKey(WelcomeKeys.body));
        final imageRect = tester.getRect(
          find.byKey(WelcomeIllustration.imageKey),
        );

        expect(imageRect.top - bodyRect.bottom, closeTo(14, 0.01));
        expect(
          tester.getSize(find.byKey(WelcomeIllustration.imageKey)).width,
          closeTo(size.width, 0.01),
        );
        expect(find.byKey(WelcomeKeys.scrollView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
