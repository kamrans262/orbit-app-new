import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';
import 'package:orbit_ui/features/orbit/presentation/screens/orbit_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Home Orbits tab opens Orbit without app route patching', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pumpAndSettle();

    final orbitsLabel = find.text('Orbits');
    expect(orbitsLabel, findsOneWidget);
    await tester.ensureVisible(orbitsLabel);
    await tester.tap(orbitsLabel);
    await tester.pumpAndSettle();

    expect(find.byType(OrbitScreen), findsOneWidget);
    expect(find.byKey(OrbitKeys.bottomNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Orbit Home tab naturally returns to Home', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orbits'));
    await tester.pumpAndSettle();
    expect(find.byType(OrbitScreen), findsOneWidget);

    final homeLabel = find.text('Home');
    await tester.ensureVisible(homeLabel);
    await tester.tap(homeLabel);
    await tester.pumpAndSettle();

    expect(find.byType(OrbitScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
