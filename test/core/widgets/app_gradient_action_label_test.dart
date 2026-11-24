import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_theme.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/core/widgets/app_gradient_action_label.dart';

void main() {
  testWidgets('enabled default action uses gradient, disabled stays muted', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Column(children: [
        TextButton(onPressed: () => pressed = true,
          child: const AppGradientActionLabel('Enabled')),
        const TextButton(onPressed: null,
          child: AppGradientActionLabel('Disabled')),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const AppGradientActionLabel('Warning')),
      ])),
    ));
    Finder shaderFor(String label) => find.ancestor(
      of: find.text(label), matching: find.byType(ShaderMask));
    expect(shaderFor('Enabled'), findsOneWidget);
    expect(shaderFor('Disabled'), findsNothing);
    expect(shaderFor('Warning'), findsNothing);
    await tester.tap(find.text('Enabled'));
    expect(pressed, isTrue);
  });

  testWidgets('iOS selects the native emoji font', (tester) async {
    String? font;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
      home: Builder(builder: (context) {
        font = AppTypography.emojiFontFamily(context);
        return const SizedBox();
      }),
    ));
    expect(font, 'Apple Color Emoji');
  });
}
