import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';

void main() {
  testWidgets('Home Explore quick action opens Explore screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen.demo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);
    await tester.tap(find.text('Explore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('Upcoming Meetups'), findsOneWidget);
    expect(find.text('Meet people.\nDo more\ntogether.'), findsOneWidget);
  });
}
