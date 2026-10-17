import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';

void main() {
  testWidgets('Home notification opens Request with the shared route', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pump();

    await tester.tap(find.byKey(HomeKeys.notificationButton));
    await tester.pumpAndSettle();

    expect(find.text('Request'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Circles'), findsOneWidget);
  });

  testWidgets('Home greeting keeps emoji fallback fonts under Poppins', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pump();

    final greeting = tester.widget<Text>(find.byKey(HomeKeys.greeting));
    expect(greeting.style?.fontFamilyFallback, isNotNull);
    expect(greeting.style!.fontFamilyFallback, contains('Noto Color Emoji'));
  });
}
