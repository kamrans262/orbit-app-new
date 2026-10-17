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

    await tester.longPress(find.byKey(const Key('message')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
