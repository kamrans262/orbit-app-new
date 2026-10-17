import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/share_moments_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome2_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  Future<void> usePhoneViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Get Started opens the second welcome screen', (tester) async {
    await usePhoneViewport(tester);

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

  testWidgets('second welcome Next opens Share Moments', (tester) async {
    await usePhoneViewport(tester);

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    final getStartedButton = find.byKey(WelcomeKeys.getStartedButton);
    await tester.ensureVisible(getStartedButton);
    await tester.pumpAndSettle();
    expect(getStartedButton.hitTestable(), findsOneWidget);
    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();

    final nextButton = find.byKey(Welcome2Keys.nextButton);
    expect(nextButton, findsOneWidget);
    await tester.ensureVisible(nextButton);
    await tester.pumpAndSettle();
    expect(nextButton.hitTestable(), findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.byType(ShareMomentsScreen), findsOneWidget);
    expect(find.text('Share Moments'), findsOneWidget);
    expect(find.byKey(ShareMomentsKeys.image), findsOneWidget);
  });
}
