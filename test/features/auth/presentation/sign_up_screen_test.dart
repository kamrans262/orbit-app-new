import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_account_switch.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_card.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_divider.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_social_buttons.dart';

void main() {
  Widget buildScreen() {
    return MaterialApp(
      home: SignUpScreen(
        onSignUp: (_, _, _) {},
        onAppleSignUp: () {},
        onGoogleSignUp: () {},
        onLogIn: () {},
      ),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Sign Up reuses the shared authentication components', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.byType(AuthDivider), findsOneWidget);
    expect(find.byType(AuthSocialButtons), findsOneWidget);
    expect(find.byType(AuthAccountSwitch), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email or Phone'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('Sign Up stays overflow-safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      await setPhoneSize(tester, size);
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint('FULL_FLEX_DETAILS: ${details.toString()}');
        previousErrorHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousErrorHandler);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byKey(SignUpKeys.card), findsOneWidget);
      final diagnostics = tester.takeException();
      if (diagnostics != null) {
        // Temporary diagnostic to isolate the small-screen RenderFlex.
        debugPrint('AUTH_DIAGNOSTIC: ${diagnostics.toString()}');
        if (diagnostics is FlutterError) {
          for (final detail in diagnostics.diagnostics) {
            debugPrint('AUTH_DETAIL: ${detail.toStringDeep(minLevel: DiagnosticLevel.info)}');
          }
        }
      }
      expect(diagnostics, isNull);
    });
  }

  testWidgets('password visibility updates immediately', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final textFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(textFields.last.obscureText, isTrue);

    final visibility = find.byKey(SignUpKeys.passwordVisibility);
    await tester.ensureVisible(visibility);
    expect(visibility.hitTestable(), findsOneWidget);
    await tester.tap(visibility);
    await tester.pump();

    final updatedFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(updatedFields.last.obscureText, isFalse);
    expect(tester.takeException(), isNull);
  });
}
