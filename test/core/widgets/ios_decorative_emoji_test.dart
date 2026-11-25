import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_header.dart';
import 'package:orbit_ui/features/ping/presentation/screens/ping_screen.dart';

void main() {
  testWidgets('iOS auth heading uses a bundled waving hand icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: const Scaffold(body: AuthHeader(
        heading: 'Welcome back \u{1F44B}',
        subtitle: 'Log in to continue',
      )),
    ));
    expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS Ping options render bundled icons instead of emoji glyphs',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: PingScreen.demo(),
    ));
    for (final icon in [
      Icons.waving_hand_rounded, Icons.location_on_rounded,
      Icons.directions_car_rounded, Icons.alarm_rounded,
      Icons.favorite_rounded, Icons.warning_amber_rounded,
    ]) {
      expect(find.byIcon(icon), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
