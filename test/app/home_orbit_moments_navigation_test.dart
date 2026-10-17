import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';
import 'package:orbit_ui/features/moments/presentation/screens/moments_screen.dart';
import 'package:orbit_ui/features/orbit/presentation/screens/orbit_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Home Moments tab opens Moments and Home returns correctly', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Moments').last);
    await tester.pumpAndSettle();
    expect(find.byType(MomentsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(MomentsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home Orbits then Moments keeps shared tab navigation working', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orbits'));
    await tester.pumpAndSettle();
    expect(find.byType(OrbitScreen), findsOneWidget);

    await tester.tap(find.text('Moments'));
    await tester.pumpAndSettle();
    expect(find.byType(MomentsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Orbits'));
    await tester.pumpAndSettle();
    expect(find.byType(OrbitScreen), findsOneWidget);
    expect(find.byType(MomentsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
