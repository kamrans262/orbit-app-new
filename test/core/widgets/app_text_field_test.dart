import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_text_field.dart';

void main() {
  testWidgets('AppTextField keeps the 49px shared visual contract', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Best Friends');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: AppTextField(
              label: 'Circle Name:',
              labelKey: const Key('label'),
              fieldKey: const Key('field'),
              controller: controller,
              suffixIcon: const Icon(Icons.favorite_rounded),
              keyboardType: TextInputType.text,
              validator: (value) => value == 'Best Friends' ? null : 'Invalid',
            ),
          ),
        ),
      ),
    );

    final fieldRect = tester.getRect(find.byKey(const Key('field')));
    final label = tester.widget<Text>(find.byKey(const Key('label')));
    final textField = tester.widget<TextField>(find.byType(TextField));
    final container = tester.widget<Container>(find.byKey(const Key('field')));
    final decoration = container.decoration! as BoxDecoration;

    expect(fieldRect.height, 49);
    expect(decoration.color, Colors.white);
    expect(decoration.borderRadius, BorderRadius.circular(30));
    expect(decoration.boxShadow?.single.blurRadius, 2);
    expect(decoration.boxShadow?.single.spreadRadius, 0);
    expect(decoration.boxShadow?.single.color, const Color(0x1A000000));

    expect(label.style?.fontFamily, 'Poppins');
    expect(label.style?.fontSize, 14);
    expect(label.style?.fontWeight, FontWeight.w500);
    expect(label.style?.color, const Color(0xFF0F1724));

    expect(textField.style?.fontFamily, 'Poppins');
    expect(textField.style?.fontSize, 15);
    expect(textField.style?.height, isNull);
    expect(textField.style?.fontWeight, FontWeight.w400);
    expect(textField.style?.color, const Color(0xFF0F1724));
    expect(textField.textAlignVertical, TextAlignVertical.center);
    expect(textField.strutStyle, isNull);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'auth-style placeholder is vertically centered even with suffix icon',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AppTextField(
                  label: 'Password',
                  fieldKey: const Key('field'),
                  hintText: '••••••••',
                  obscureText: true,
                  suffixIcon: SizedBox.square(
                    dimension: AppTextField.referenceHeight,
                    child: Icon(Icons.visibility_off_outlined, size: 19),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fieldRect = tester.getRect(find.byKey(const Key('field')));
      final hintRect = tester.getRect(find.text('••••••••'));

      final topSpace = hintRect.top - fieldRect.top;
      final bottomSpace = fieldRect.bottom - hintRect.bottom;

      expect(fieldRect.height, 49);
      expect((topSpace - bottomSpace).abs(), lessThanOrEqualTo(1.0));
      expect(hintRect.center.dy, closeTo(fieldRect.center.dy, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'entered text uses natural Poppins metrics instead of forced strut',
    (tester) async {
      final controller = TextEditingController(text: 'Emma');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AppTextField(
                  fieldKey: const Key('field'),
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlignVertical, TextAlignVertical.center);
      expect(textField.strutStyle, isNull);
      expect(textField.style?.height, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AppTextField keeps trailing action password and validation support',
    (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                label: 'Password',
                hintText: 'Password',
                obscureText: true,
                labelTrailing: const Text('Forgot Password?'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
