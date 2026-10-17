import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/widgets/quick_action_card.dart';

void main() {
  testWidgets('Home Ping quick action opens Ping screen', (tester) async {
    const data = QuickActionData(
      id: 'ping',
      title: 'Ping',
      icon: Icons.bolt_rounded,
      iconColor: Color(0xFF7C3AED),
      iconBackground: Color(0xFFF2EAFE),
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
    await tester.tap(find.text('Ping'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Custom Message'), findsOneWidget);
  });

  testWidgets('Home Moment quick action opens Moments screen', (tester) async {
    const data = QuickActionData(
      id: 'moment',
      title: 'Moment',
      icon: Icons.photo_camera_outlined,
      iconColor: Color(0xFF16B88B),
      iconBackground: Color(0xFFE2F8F2),
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
    await tester.tap(find.text('Moment'));
    await tester.pumpAndSettle();
    expect(find.text('Moments'), findsOneWidget);
  });
}
