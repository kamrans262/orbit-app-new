import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/share_moments_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome2_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/your_circle_screen.dart';

void main() {
  Widget buildWelcome1() {
    return MaterialApp(
      home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
    );
  }

  Widget buildWelcome2() {
    return MaterialApp(home: Welcome2Screen(onNext: () {}));
  }

  Widget buildShareMoments() {
    return MaterialApp(home: ShareMomentsScreen(onNext: () {}));
  }

  Widget buildYourCircle() {
    return MaterialApp(home: YourCircleScreen(onNext: () {}));
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('your_circle.png is available in the Flutter asset bundle', (
    tester,
  ) async {
    await tester.pumpWidget(buildYourCircle());
    final data = await rootBundle.load('assets/your_circle.png');
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('Your Circle keeps exact heading body image spacing', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildYourCircle());
    await tester.pumpAndSettle();

    final headingRect = tester.getRect(find.byKey(YourCircleKeys.heading));
    final bodyRect = tester.getRect(find.byKey(YourCircleKeys.body));
    final imageRect = tester.getRect(find.byKey(YourCircleKeys.image));

    expect(bodyRect.top - headingRect.bottom, closeTo(10, 0.01));
    expect(imageRect.top - bodyRect.bottom, closeTo(66, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'all onboarding primary buttons including Your Circle align at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);

        await tester.pumpWidget(buildWelcome1());
        await tester.pumpAndSettle();
        final welcome1ButtonTop = tester
            .getRect(find.byKey(WelcomeKeys.getStartedButton))
            .top;
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildWelcome2());
        await tester.pumpAndSettle();
        final welcome2ButtonTop = tester
            .getRect(find.byKey(Welcome2Keys.nextButton))
            .top;
        expect(welcome2ButtonTop, closeTo(welcome1ButtonTop, 0.01));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildShareMoments());
        await tester.pumpAndSettle();
        final shareMomentsButtonTop = tester
            .getRect(find.byKey(ShareMomentsKeys.nextButton))
            .top;
        expect(shareMomentsButtonTop, closeTo(welcome1ButtonTop, 0.01));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildYourCircle());
        await tester.pumpAndSettle();
        final imageRect = tester.getRect(find.byKey(YourCircleKeys.image));
        final yourCircleButtonRect = tester.getRect(
          find.byKey(YourCircleKeys.nextButton),
        );

        expect(yourCircleButtonRect.top, closeTo(welcome1ButtonTop, 0.01));
        expect(yourCircleButtonRect.top - imageRect.bottom, closeTo(0, 0.01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('shared onboarding background remains #F9F9F9', () {
    expect(AppColors.background, const Color(0xFFF9F9F9));
  });
}
