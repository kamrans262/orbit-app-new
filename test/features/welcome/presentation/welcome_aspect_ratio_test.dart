import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('welcome illustration preserves its intrinsic aspect ratio', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    final data = await rootBundle.load('assets/welcome.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final intrinsicRatio = frame.image.width / frame.image.height;
    frame.image.dispose();
    codec.dispose();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final imageRect = tester.getRect(find.byKey(WelcomeIllustration.imageKey));
    expect(imageRect.width / imageRect.height, closeTo(intrinsicRatio, 0.02));
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'welcome image remains attached to primary button without overflow at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final imageRect = tester.getRect(
          find.byKey(WelcomeIllustration.imageKey),
        );
        final buttonRect = tester.getRect(
          find.byKey(WelcomeKeys.getStartedButton),
        );
        final bodyRect = tester.getRect(find.byKey(WelcomeKeys.body));

        expect(imageRect.top - bodyRect.bottom, closeTo(14, 0.75));
        expect(buttonRect.top - imageRect.bottom, closeTo(0, 0.75));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
