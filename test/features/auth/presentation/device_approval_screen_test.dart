import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/auth/presentation/screens/device_registration_screen.dart';

void main() {
  testWidgets('A pending second device waits for trusted-device approval',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var attempts = 0;
    var checks = 0;
    var continued = 0;
    var trusted = false;
    await tester.pumpWidget(MaterialApp(home: DeviceRegistrationScreen(
      onBack: () {},
      onContinue: () => continued++,
      onRegisterDevice: () async {
        attempts++;
        throw OrbitIdentityException('Waiting for trusted-device approval.', 403);
      },
      onCheckApproval: () async {
        checks++;
        return trusted;
      },
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(DeviceRegistrationKeys.action));
    await tester.tap(find.byKey(DeviceRegistrationKeys.action));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(continued, 0);
    expect(find.text('Check Approval'), findsOneWidget);
    expect(find.textContaining('Waiting for approval'), findsOneWidget);

    await tester.tap(find.byKey(DeviceRegistrationKeys.action));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(continued, 0);
    trusted = true;
    await tester.tap(find.byKey(DeviceRegistrationKeys.action));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(attempts, 1);
    expect(continued, 1);
    expect(tester.takeException(), isNull);
  });
}
