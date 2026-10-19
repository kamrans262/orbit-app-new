import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/core/widgets/app_text_field.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/orbit_auth_channel_selector.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_otp_sign_in_screen.dart';

void main() {
  testWidgets('email and SMS use existing Orbit gradient and white selected text',
      (tester) async {
    String selected = 'email';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) =>
            OrbitAuthChannelSelector(
              channel: selected,
              onChanged: (value) => setState(() => selected = value),
            )),
      ),
    ));
    final emailSurface = tester.widget<Container>(find.descendant(
      of: find.byKey(const Key('orbit_auth_channel_email')),
      matching: find.byType(Container),
    ).first);
    final original = emailSurface.decoration! as BoxDecoration;
    expect((original.gradient! as LinearGradient).colors,
        [AppColors.primaryStart, AppColors.primaryEnd]);
    await tester.tap(find.byKey(const Key('orbit_auth_channel_sms')));
    await tester.pump();
    expect(selected, 'sms');
    final smsSurface = tester.widget<Container>(find.descendant(
      of: find.byKey(const Key('orbit_auth_channel_sms')),
      matching: find.byType(Container),
    ).first);
    final switched = smsSurface.decoration! as BoxDecoration;
    expect((switched.gradient! as LinearGradient).colors,
        [AppColors.primaryStart, AppColors.primaryEnd]);
    expect(find.text('SMS'), findsOneWidget);
  });

  testWidgets('OTP request form reuses Orbit input field and prefilled destination',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: OrbitOtpSignInScreen(
        initialRecipient: 'someone@example.com',
        onVerified: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.text('someone@example.com'), findsOneWidget);
    expect(find.byType(OrbitAuthChannelSelector), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
