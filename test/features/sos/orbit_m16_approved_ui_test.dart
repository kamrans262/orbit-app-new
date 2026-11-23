import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/sos/presentation/screens/orbit_live_sos_contacts_screen.dart';
import 'package:orbit_ui/features/sos/presentation/screens/orbit_live_sos_inbox_screen.dart';
import 'package:orbit_ui/features/sos/data/orbit_sos_repository.dart';
import 'package:orbit_ui/features/friends/data/orbit_social_repository.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/core/widgets/app_screen_header.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/orbit_circle_sheet.dart';

class _ApprovedUiSosRepository extends OrbitSosRepository {
  @override
  Future<String> owner() async=>'owner-1';
  @override
  Future<List<OrbitSosContact>> contacts() async=>[
    const OrbitSosContact(
      id:'contact-1',ownerId:'owner-1',recipientId:'friend-1',
      state:'accepted'),
  ];
  @override
  Future<List<OrbitSosIncident>> incidents() async=>[
    OrbitSosIncident.fromJson({
      'id':'alert-1','status':'active','my_role':'responder',
      'initiator_name':'Verified friend','revision':1,
      'created_at':'2026-11-23T12:00:00Z',
      'server_accepted':true,
      'responder_acknowledgements':0,
      'push_provider_accepted_jobs':0,
      'in_app_available_for_eligible_responders':true,
      'location_sharing_active':false,
      'recording_consented':false,'recording_active':false,
    }),
  ];
}

class _ApprovedUiSocialRepository extends OrbitSocialRepository {
  @override
  Future<OrbitFriendPage<OrbitPerson>> friends({int page=1}) async=>
    const OrbitFriendPage<OrbitPerson>(
      items:[OrbitPerson(id:'friend-1',name:'Verified friend',
        username:'friend')],
      page:1,hasMore:false);
}

void main(){
  Future<void> size(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390,844));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
  }

  testWidgets('M16 contacts reuse approved Orbit header, CTA and Circle rows',
      (tester) async {
    await size(tester);
    await tester.pumpWidget(MaterialApp(
      home:OrbitLiveSosContactsScreen(
        repository:_ApprovedUiSosRepository(),
        social:_ApprovedUiSocialRepository()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AppScreenHeader),findsOneWidget);
    expect(find.byType(AppPrimaryButton),findsOneWidget);
    expect(find.byType(OrbitCircleSheetAction),findsOneWidget);
    expect(find.textContaining('Verified friend'),findsOneWidget);
    expect(find.byType(Card),findsNothing);
    expect(find.byType(ElevatedButton),findsNothing);
    await tester.tap(find.byType(OrbitCircleSheetAction).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orbit_circle_sheet_surface')),findsOneWidget);
  });

  testWidgets('M16 SOS history reuses approved Notifications ListTile rows',
      (tester) async {
    await size(tester);
    await tester.pumpWidget(MaterialApp(
      home:OrbitLiveSosInboxScreen(repository:_ApprovedUiSosRepository()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AppScreenHeader),findsOneWidget);
    expect(find.byType(ListTile),findsOneWidget);
    expect(find.text('SOS from Verified friend'),findsOneWidget);
    expect(find.byType(Card),findsNothing);
    expect(find.byType(ElevatedButton),findsNothing);
  });
}
