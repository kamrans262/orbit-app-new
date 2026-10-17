import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/check_in/presentation/screens/check_in_screen.dart';
import 'package:orbit_ui/features/orbit/presentation/screens/orbit_screen.dart';

void main() {
  testWidgets('Orbit Check in opens CheckInScreen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: OrbitScreen.demo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(OrbitKeys.checkInButton));
    await tester.pumpAndSettle();

    expect(find.byType(CheckInScreen), findsOneWidget);
    expect(find.text('How are you?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
