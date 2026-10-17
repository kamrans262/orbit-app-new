import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/widgets/welcome_illustration.dart';

void main() {
  Future<void> verifySpacing(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final bodyRect = tester.getRect(find.byKey(WelcomeKeys.body));
    final imageRect = tester.getRect(find.byKey(WelcomeIllustration.imageKey));

    expect(imageRect.top - bodyRect.bottom, closeTo(20, 0.01));
    expect(tester.takeException(), isNull);
  }

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Welcome body to image gap is exactly 20px at ${size.width}x${size.height}',
      (tester) => verifySpacing(tester, size),
    );
  }
}
