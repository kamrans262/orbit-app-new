import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/chat/message_reactions.dart';

void main() {
  testWidgets('long press opens reaction picker and selection is summarized', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MessageReactionRegion(
              messageId: 'm1',
              isMine: false,
              child: SizedBox(key: Key('message'), width: 180, height: 60),
            ),
          ),
        ),
      ),
    );

    // Press the interactive reaction region, not its non-hit-testable
    // SizedBox child (Flutter 3.47 warns about direct SizedBox hits).
    await tester.longPress(find.byType(MessageReactionRegion));
    await tester.pumpAndSettle();
    expect(find.text(ChatReactionKind.heart.backendValue), findsOneWidget);

    await tester.tap(find.text(ChatReactionKind.heart.backendValue));
    await tester.pumpAndSettle();
    expect(find.text(ChatReactionKind.heart.backendValue), findsOneWidget);
  });
}
