import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_text_field.dart';

void main() {
  testWidgets('AppTextField preserves Orbit field styling and configuration', (
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

    expect(fieldRect.height, 46);
    expect(decoration.color, Colors.white);
    expect(decoration.borderRadius, BorderRadius.circular(30));
    expect(decoration.boxShadow?.single.blurRadius, 2);
    expect(label.style?.fontFamily, 'Poppins');
    expect(label.style?.fontSize, 14);
    expect(textField.style?.fontFamily, 'Poppins');
    expect(textField.style?.fontSize, 14);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AppTextField supports trailing label action without restyling field',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Password',
              hintText: 'Password',
              labelTrailing: Text('Forgot Password?'),
            ),
          ),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(tester.getSize(find.byType(Container).first).height, 46);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AppTextField supports obscured and validation states', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppTextField(
              initialValue: '',
              hintText: 'Password',
              obscureText: true,
              enabled: true,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
  });
}
