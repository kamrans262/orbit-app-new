import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/widgets/quick_action_card.dart';
import 'package:orbit_ui/features/sos/presentation/screens/sos_alert_screen.dart';

void main() {
  testWidgets('SOS quick action opens SosAlertScreen', (
    WidgetTester tester,
  ) async {
    const data = QuickActionData(
      id: 'sos',
      title: 'SOS',
      icon: Icons.sos,
      iconColor: Colors.red,
      iconBackground: Color(0xFFFFEEEE),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickActionCard(data: data, onTap: () {}),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(QuickActionCard));
    await tester.pumpAndSettle();

    expect(find.byType(SosAlertScreen), findsOneWidget);
    expect(find.text('SOS Alert'), findsOneWidget);
  });
}
