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
  testWidgets('Lost-only-device recovery asks for password and OTP before Home',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requested = 0;
    var recovered = 0;
    var completed = 0;
    await tester.pumpWidget(MaterialApp(
      home: DeviceRegistrationScreen(
        onBack: () {},
        onContinue: () => completed++,
        onRegisterDevice: () async {
          throw OrbitIdentityException('Pending approval', 403);
        },
        onCheckApproval: () async => false,
        onRequestRecoveryCode: (recipient, password) async {
          expect(recipient, 'member@example.test');
          expect(password, 'ExistingPassword123');
          requested++;
        },
        onCompleteRecovery: (recipient, password, code) async {
          expect(recipient, 'member@example.test');
          expect(password, 'ExistingPassword123');
          expect(code, '472819');
          recovered++;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeviceRegistrationKeys.action));
    await tester.pumpAndSettle();
    expect(find.byKey(DeviceRegistrationKeys.recoveryLink), findsOneWidget);
    await tester.ensureVisible(find.byKey(DeviceRegistrationKeys.recoveryLink));
    await tester.tap(find.byKey(DeviceRegistrationKeys.recoveryLink));
    await tester.pumpAndSettle();

    expect(find.text('Recover device access'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'member@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'ExistingPassword123');
    await tester.ensureVisible(find.byKey(DeviceRegistrationKeys.recoveryAction));
    await tester.tap(find.byKey(DeviceRegistrationKeys.recoveryAction));
    await tester.pumpAndSettle();
    expect(requested, 1);
    expect(recovered, 0);
    expect(completed, 0);

    await tester.enterText(find.byType(TextField).at(2), '472819');
    await tester.ensureVisible(find.byKey(DeviceRegistrationKeys.recoveryAction));
    await tester.tap(find.byKey(DeviceRegistrationKeys.recoveryAction));
    await tester.pumpAndSettle();
    expect(recovered, 1);
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recovery failure cannot bypass pending device approval',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var completed = 0;
    await tester.pumpWidget(MaterialApp(
      home: DeviceRegistrationScreen(
        onBack: () {},
        onContinue: () => completed++,
        onRegisterDevice: () async =>
          throw OrbitIdentityException('Pending approval', 403),
        onCheckApproval: () async => false,
        onRequestRecoveryCode: (recipient, password) async {},
        onCompleteRecovery: (recipient, password, code) async =>
          throw OrbitIdentityException('Invalid or expired recovery code.', 422),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeviceRegistrationKeys.action));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(DeviceRegistrationKeys.recoveryLink));
    await tester.tap(find.byKey(DeviceRegistrationKeys.recoveryLink));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'member@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'ExistingPassword123');
    await tester.ensureVisible(find.byKey(DeviceRegistrationKeys.recoveryAction));
    await tester.tap(find.byKey(DeviceRegistrationKeys.recoveryAction));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '000000');
    await tester.ensureVisible(find.byKey(DeviceRegistrationKeys.recoveryAction));
    await tester.tap(find.byKey(DeviceRegistrationKeys.recoveryAction));
    await tester.pumpAndSettle();
    expect(find.text('Invalid or expired recovery code.'), findsOneWidget);
    expect(completed, 0);
    expect(tester.takeException(), isNull);
  });

}
