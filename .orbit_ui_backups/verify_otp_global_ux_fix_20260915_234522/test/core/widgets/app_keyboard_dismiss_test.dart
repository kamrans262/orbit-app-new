import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_keyboard_dismiss.dart';

void main() {
  testWidgets('dismisses focus outside input without blocking controls', (
    tester,
  ) async {
    var buttonTaps = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardDismiss(
          child: Scaffold(
            body: Column(
              children: <Widget>[
                TextField(
                  key: const Key('keyboard_test_field'),
                  focusNode: focusNode,
                ),
                Container(
                  key: const Key('keyboard_test_blank'),
                  width: 200,
                  height: 80,
                  color: Colors.transparent,
                ),
                ElevatedButton(
                  key: const Key('keyboard_test_button'),
                  onPressed: () => buttonTaps++,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final field = find.byKey(const Key('keyboard_test_field'));
    await tester.tap(field);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('keyboard_test_blank')));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    await tester.tap(find.byKey(const Key('keyboard_test_button')));
    await tester.pump();
    expect(buttonTaps, 1);
    expect(tester.takeException(), isNull);
  });
}
