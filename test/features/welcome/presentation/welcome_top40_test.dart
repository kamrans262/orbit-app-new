import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/widgets/welcome_illustration.dart';

void main() {
  Widget buildScreen() => MaterialApp(
    home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
  );

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
      'Welcome starts 40px below SafeArea and stays scroll-safe at $size',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final logoRect = tester.getRect(find.byKey(WelcomeKeys.logo));
        final safeTop = MediaQuery.of(
          tester.element(find.byType(WelcomeScreen)),
        ).padding.top;
        expect(logoRect.top - safeTop, closeTo(40, 0.01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('body to image is 14px and image touches primary button', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final bodyRect = tester.getRect(find.byKey(WelcomeKeys.body));
    final imageRect = tester.getRect(find.byKey(WelcomeIllustration.imageKey));
    final buttonRect = tester.getRect(find.byKey(WelcomeKeys.getStartedButton));

    expect(imageRect.top - bodyRect.bottom, closeTo(14, 0.01));
    expect(buttonRect.top - imageRect.bottom, closeTo(0, 0.01));
    expect(tester.takeException(), isNull);
  });
}
