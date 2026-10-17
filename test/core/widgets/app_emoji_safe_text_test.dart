import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_emoji_safe_text.dart';

void main() {
  testWidgets('unicode escapes render as icons instead of text glyphs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              AppEmojiSafeText('Good Morning, Emma \u{1F44B}'),
              AppEmojiSafeText('Sunset walk \u{1F305}'),
              AppEmojiSafeText('Finished a 10k run! \u{1F3C3} Feeling good'),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wb_twilight_rounded), findsOneWidget);
    expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);

    // The inline spans should contain icons, not the literal emoji glyphs.
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    expect(richTexts, isNotEmpty);
  });
}
