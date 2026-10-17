import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_emoji_safe_text.dart';

void main() {
  testWidgets('renders known decorative emoji as icons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              AppEmojiSafeText('Good Morning, Emma 👋'),
              AppEmojiSafeText('Sunset walk 🌅'),
              AppEmojiSafeText('Finished a 10k 🏃'),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
  });
}
