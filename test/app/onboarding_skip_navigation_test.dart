import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/core/widgets/app_secondary_button.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/create_circle_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/circle_permission_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/invite_people_screen.dart';

void main() {
  Future<void> size(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> press(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Create Circle keeps primary button and secondary Skip',
      (tester) async {
    await size(tester);
    var completed = 0;
    var skipped = 0;
    await tester.pumpWidget(MaterialApp(home: CreateCircleScreen(
      onNext: () => completed++,
      onSkip: () => skipped++,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(AppPrimaryButton), findsOneWidget);
    expect(find.byType(AppSecondaryButton), findsOneWidget);
    expect(find.text('Create Circle'), findsOneWidget);
    await press(tester, CreateCircleKeys.skipButton);
    expect(skipped, 1);
    expect(completed, 0);
    await press(tester, CreateCircleKeys.nextButton);
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Circle Permission keeps primary action and secondary Skip',
      (tester) async {
    await size(tester);
    var continued = 0;
    var skipped = 0;
    await tester.pumpWidget(MaterialApp(home: CirclePermissionScreen(
      onBack: () {},
      onCreateCircle: () => continued++,
      onSkip: () => skipped++,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(AppPrimaryButton), findsOneWidget);
    expect(find.byType(AppSecondaryButton), findsOneWidget);
    await press(tester, CirclePermissionKeys.skipButton);
    expect(skipped, 1);
    expect(continued, 0);
    await press(tester, CirclePermissionKeys.createCircleButton);
    expect(continued, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invite People offers Done and secondary Skip, without mock send',
      (tester) async {
    await size(tester);
    var done = 0;
    var skipped = 0;
    var inviteActions = 0;
    await tester.pumpWidget(MaterialApp(home: InvitePeopleScreen(
      onInviteByContacts: () => inviteActions++,
      onInviteByQrCode: () => inviteActions++,
      onInviteByLink: () => inviteActions++,
      onInviteByUsername: () => inviteActions++,
      onAddPerson: (_) => inviteActions++,
      onOpenLogin: () {},
      onDone: () => done++,
      onSkip: () => skipped++,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(AppPrimaryButton), findsOneWidget);
    expect(find.byType(AppSecondaryButton), findsOneWidget);
    await press(tester, InvitePeopleKeys.skipButton);
    expect(skipped, 1);
    expect(done, 0);
    expect(inviteActions, 0);
    await press(tester, InvitePeopleKeys.doneButton);
    expect(done, 1);
    expect(inviteActions, 0);
    expect(tester.takeException(), isNull);
  });
}
