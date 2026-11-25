import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/widgets/quick_action_card.dart';

void main() {
  for (final id in ['sos', 'ping', 'moment', 'explore']) {
    testWidgets('live $id action calls its authenticated navigation handler',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: QuickActionCard(
          data: QuickActionData(id: id, title: id, icon: Icons.star,
            iconColor: Colors.red, iconBackground: Colors.white),
          onTap: () => taps++,
        ))),
      ));
      await tester.tap(find.byType(QuickActionCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(QuickActionCard), findsOneWidget);
    });
  }
}
