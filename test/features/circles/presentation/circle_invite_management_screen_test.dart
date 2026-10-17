import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/domain/models/circle_invite.dart';
import 'package:orbit_ui/features/circles/presentation/screens/circle_invite_management_screen.dart';

void main() {
  testWidgets('renders the Figma demo and switches invite tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CircleInviteManagementScreen.demo()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Circle Invite management'), findsOneWidget);
    expect(
      find.byKey(CircleInviteManagementKeys.segmentedControl),
      findsOneWidget,
    );
    expect(
      find.byKey(CircleInviteManagementKeys.tile('sent-emma')),
      findsOneWidget,
    );
    expect(
      find.byKey(CircleInviteManagementKeys.status('sent-emma')),
      findsOneWidget,
    );
    expect(
      find.byKey(CircleInviteManagementKeys.tile('sent-olivia')),
      findsOneWidget,
    );
    expect(
      find.byKey(CircleInviteManagementKeys.tile('sent-oliviia')),
      findsOneWidget,
    );

    final pendingSegment = find.descendant(
      of: find.byKey(CircleInviteManagementKeys.segmentedControl),
      matching: find.text('Pending'),
    );
    await tester.tap(pendingSegment);
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      find.byKey(CircleInviteManagementKeys.tile('pending-emma')),
      findsOneWidget,
    );

    final acceptedSegment = find.descendant(
      of: find.byKey(CircleInviteManagementKeys.segmentedControl),
      matching: find.text('Accepted'),
    );
    await tester.tap(acceptedSegment);
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      find.byKey(CircleInviteManagementKeys.tile('accepted-olivia')),
      findsOneWidget,
    );
  });

  testWidgets('invite row opens a real invite details destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CircleInviteManagementScreen.demo()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CircleInviteManagementKeys.tile('sent-emma')));
    await tester.pumpAndSettle();

    expect(find.text('Invite details'), findsOneWidget);
    expect(find.text('Emma'), findsOneWidget);
  });

  testWidgets('stays overflow-safe at 320 by 568 with a long backend name', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final longNameInvite = CircleInvite(
      id: 'long-name',
      userId: 'long-name-user',
      userName: 'A very long localized backend person name that must ellipsize',
      avatarUrl: 'assets/Emma.png',
      status: CircleInviteStatus.accepted,
      createdAt: DateTime(2026, 9, 17),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CircleInviteManagementScreen(
          sent: CircleInviteTabData(invites: <CircleInvite>[longNameInvite]),
          pending: const CircleInviteTabData(
            state: CircleInviteViewState.empty,
          ),
          accepted: const CircleInviteTabData(
            state: CircleInviteViewState.empty,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(CircleInviteManagementKeys.tile('long-name')),
      findsOneWidget,
    );
  });

  testWidgets('supports loading error and empty backend states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CircleInviteManagementScreen(
          sent: CircleInviteTabData(state: CircleInviteViewState.loading),
          pending: CircleInviteTabData(
            state: CircleInviteViewState.error,
            errorMessage: 'Network unavailable',
          ),
          accepted: CircleInviteTabData(state: CircleInviteViewState.empty),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(CircleInviteManagementKeys.list(CircleInviteTab.sent)),
      findsOneWidget,
    );

    final pendingSegment = find.descendant(
      of: find.byKey(CircleInviteManagementKeys.segmentedControl),
      matching: find.text('Pending'),
    );
    await tester.tap(pendingSegment);
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('Network unavailable'), findsOneWidget);

    final acceptedSegment = find.descendant(
      of: find.byKey(CircleInviteManagementKeys.segmentedControl),
      matching: find.text('Accepted'),
    );
    await tester.tap(acceptedSegment);
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('No accepted invites'), findsOneWidget);
  });
}
