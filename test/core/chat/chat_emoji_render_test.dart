import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/chat/chat_rich_text.dart';
import 'package:orbit_ui/core/chat/message_reactions.dart';

void main() {
  testWidgets('chat text keeps emoji as system text glyph widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatRichText(
            'Wave \u{1F30A} coffee \u{2615} party \u{1F389}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.text('\u{1F30A}'), findsOneWidget);
    expect(find.text('\u{2615}'), findsOneWidget);
    expect(find.text('\u{1F389}'), findsOneWidget);
    expect(find.byIcon(Icons.waves_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reaction picker renders actual emoji values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageReactionPicker(selected: null, onSelected: (_) {}),
        ),
      ),
    );

    expect(find.text('\u{2764}\u{FE0F}'), findsOneWidget);
    expect(find.text('\u{1F44D}'), findsOneWidget);
    expect(find.text('\u{1F602}'), findsOneWidget);
    expect(find.text('\u{1F62E}'), findsOneWidget);
    expect(find.text('\u{1F622}'), findsOneWidget);
    expect(find.text('\u{1F44E}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
