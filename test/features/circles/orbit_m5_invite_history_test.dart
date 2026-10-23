import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/data/orbit_circle_repository.dart';
import 'package:orbit_ui/features/circles/domain/models/circle_invite.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/invite_status_badge.dart';
import 'package:orbit_ui/features/circles/presentation/screens/circle_invite_management_screen.dart';

void main() {
  testWidgets('Backend expired and revoked invitations show truthful terminal badges',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Column(
        children:[
          InviteStatusBadge(status:CircleInviteStatus.expired),
          InviteStatusBadge(status:CircleInviteStatus.revoked),
        ],
      ))));
      expect(find.text('Expired'),findsOneWidget);
      expect(find.text('Revoked'),findsOneWidget);
    });

  testWidgets('Historical and non-issuer invitations are not tappable',
    (tester) async {
      var tapped=0;
      final denied = CircleInvite(
        id:'revoked', userId:'user-1',userName:'A',
        avatarUrl:'',status:CircleInviteStatus.revoked,
        createdAt:DateTime(2026,10,1),
      );
      await tester.pumpWidget(MaterialApp(home:CircleInviteManagementScreen(
        sent:CircleInviteTabData(invites:[denied]),
        pending:const CircleInviteTabData(invites:[]),
        accepted:const CircleInviteTabData(invites:[]),
        onBack:(){},
        onInvitePressed:(_){tapped++;},
        canOpenInvite:(invite)=>invite.status==CircleInviteStatus.pending,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Revoked'),findsOneWidget);
      await tester.tap(find.byKey(CircleInviteManagementKeys.tile('revoked')));
      await tester.pumpAndSettle();
      expect(tapped,0);
    });

  test('API maps invitation issuer permission but never infers it from pending state',() {
    final pending=OrbitCircleInvite.fromJson({
      'id':'invite-1','status':'pending','can_revoke':false,
    });
    final expired=OrbitCircleInvite.fromJson({
      'id':'invite-2','status':'expired','can_revoke':false,
    });
    expect(pending.canRevoke,isFalse);
    expect(expired.canRevoke,isFalse);
    expect(expired.status,'expired');
  });
}
