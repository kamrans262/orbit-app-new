import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome2_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  testWidgets('Get Started opens the second welcome screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    final getStartedButton = find.byKey(WelcomeKeys.getStartedButton);
    expect(getStartedButton, findsOneWidget);

    await tester.ensureVisible(getStartedButton);
    await tester.pumpAndSettle();

    expect(getStartedButton.hitTestable(), findsOneWidget);
    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();

    expect(find.byType(Welcome2Screen), findsOneWidget);
    expect(find.text('Live. Share. Protect'), findsOneWidget);
  });
}
