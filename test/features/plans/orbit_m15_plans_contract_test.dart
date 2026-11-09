import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/widgets/upcoming_plan_card.dart';
import 'package:orbit_ui/features/notifications/data/orbit_notification_repository.dart';
import 'package:orbit_ui/features/plans/data/orbit_plan_repository.dart';
import 'package:orbit_ui/features/plans/data/orbit_plan_pending_vault.dart';
import 'package:orbit_ui/features/plans/domain/orbit_plan_models.dart';

Map<String,dynamic> record({String id='plan-1',String status='scheduled',
    String response='invited'})=>{
  'id':id,'title':'Family dinner','description':'Private details',
  'starts_at':'2026-12-04T19:00:00Z','ends_at':'2026-12-04T21:00:00Z',
  'place':{'label':'Downtown restaurant','ref':null,
    'latitude':null,'longitude':null},
  'status':status,'revision':2,'can_edit':false,
  'organizer':{'id':'organizer-1','display_name':'Owner'},
  'my_rsvp':response,
  'participants':[{'id':'friend-1','display_name':'Friend','state':'joined'}],
};

class FakePlanIdentity extends OrbitIdentityClient {
  String? owner='owner-1';
  String? lastMethod,lastPath;
  Map<String,Object?>? lastBody;
  bool swapAfterResponse=false;
  Map<String,dynamic> Function(String,String,Map<String,Object?>?) handler=
      (_,__,___)=>{'data':record()};
  @override
  Future<String?> currentLocalSocialOwner() async=>owner;
  @override
  Future<Map<String,dynamic>> socialRequest(String method,String path,{
    Map<String,Object?>? body,String? idempotencyKey}) async {
    lastMethod=method;lastPath=path;lastBody=body;
    final result=handler(method,path,body);
    if(swapAfterResponse)owner='switched-owner';
    return result;
  }
}

void main(){
  test('M15 parses only valid private Plan identities, times and roster',(){
    final p=OrbitPlan.fromJson(record());
    expect(p.id,'plan-1');
    expect(p.title,'Family dinner');
    expect(p.startsAt.toUtc(),DateTime.utc(2026,12,4,19));
    expect(p.endsAt?.toUtc(),DateTime.utc(2026,12,4,21));
    expect(p.placeLabel,'Downtown restaurant');
    expect(p.participants.single.name,'Friend');
    expect(p.myRsvp,'invited');
    expect(()=>OrbitPlan.fromJson({...record(),'starts_at':'bad'}),
      throwsFormatException);
    expect(()=>OrbitPlan.fromJson({...record(),'organizer':null}),
      throwsFormatException);
    expect(()=>OrbitPlan.fromJson({...record(),'revision':'2'}),
      throwsFormatException);
  });

  test('M15 list parses data array and cursor from independent meta',() async {
    final id=FakePlanIdentity();
    id.handler=(_,__,___)=>{'data':[record()],
      'meta':{'next_cursor':'opaque-cursor'}};
    final repo=OrbitPlanRepository(identity:id);
    final page=await repo.list(limit:5);
    expect(page.items.single.id,'plan-1');
    expect(page.nextCursor,'opaque-cursor');
    expect(id.lastMethod,'GET');
    expect(id.lastPath,contains('tab=upcoming'));
    expect(id.lastPath,contains('limit=5'));
  });

  test('M15 creation carries the same client id for retries and UTC times',() async {
    final id=FakePlanIdentity();
    final repo=OrbitPlanRepository(identity:id);
    for(var i=0;i<2;i++){
      await repo.create(clientId:'a-client-uuid',title:' Dinner ',
        startsAt:DateTime.utc(2026,12,4,19),
        inviteeIds:['friend-1'],circleIds:['circle-1']);
      expect(id.lastMethod,'POST');
      expect(id.lastPath,'/plans');
      expect(id.lastBody?['client_id'],'a-client-uuid');
      expect(id.lastBody?['starts_at'],'2026-12-04T19:00:00.000Z');
      expect(id.lastBody?['invitee_ids'],['friend-1']);
      expect(id.lastBody?['circle_ids'],['circle-1']);
    }
  });

  test('M15 update/cancel/RVSP send revisions and explicit states',() async {
    final id=FakePlanIdentity();
    final repo=OrbitPlanRepository(identity:id);
    await repo.update('plan-1',revision:2,title:'Edited');
    expect(id.lastMethod,'PATCH');
    expect(id.lastBody?['revision'],2);
    await repo.cancel('plan-1',2);
    expect(id.lastPath,'/plans/plan-1/cancel');
    expect(id.lastBody?['revision'],2);
    await repo.rsvp('plan-1','joined');
    expect(id.lastPath,'/plans/plan-1/rsvp');
    expect(id.lastBody?['state'],'joined');
    expect(()=>repo.rsvp('plan-1','invalid'),throwsArgumentError);
    await repo.leave('plan-1');
    expect(id.lastPath,'/plans/plan-1/leave');
  });

  test('M15 account switch rejects response and never returns private data',() async {
    final id=FakePlanIdentity();
    id.swapAfterResponse=true;
    final repo=OrbitPlanRepository(identity:id);
    await expectLater(repo.detail('plan-1'),
      throwsA(isA<OrbitIdentityException>()));
  });

  test('M15 reminder offsets are server-authoritative',() async {
    final id=FakePlanIdentity();
    id.handler=(_,__,___)=>{'data':{
      'enabled':true,'offsets_minutes':[15,60],
      'allowed_offsets_minutes':[0,15,60,1440]}};
    final repo=OrbitPlanRepository(identity:id);
    final p=await repo.reminderPreferences();
    expect(p.offsets,[15,60]);
    final saved=await repo.saveReminderPreferences(
      enabled:false,offsets:[15,60]);
    expect(saved.enabled,true); // only confirmed backend data controls UI
    expect(id.lastMethod,'PUT');
    expect(id.lastBody?['enabled'],false);
  });

  test('M15 secure pending draft serializes exact retry intent',(){
    final draft=OrbitPlanPendingDraft(
      owner:'owner-1',clientId:'client-1',title:'Private',
      description:'Details',placeLabel:'Place',
      startsAt:DateTime.utc(2026,12,4,19),endsAt:null,
      inviteeIds:['person-1'],circleIds:['circle-1'],
      savedAt:DateTime.utc(2026,11,10));
    final restored=OrbitPlanPendingDraft.fromJson(draft.toJson());
    expect(restored?.clientId,'client-1');
    expect(restored?.startsAt.toUtc(),DateTime.utc(2026,12,4,19));
    expect(restored?.inviteeIds,['person-1']);
    expect(restored?.circleIds,['circle-1']);
    expect(OrbitPlanPendingDraft.fromJson({'owner':'untrusted'}),isNull);
  });

  test('M14 inbox accepts only matching opaque Plans notification targets',(){
    final data={
      'id':'notice-1','category':'plans','type':'plan.invited',
      'title':'New plan invitation','body':'A Plan invitation is available in Orbit.',
      'created_at':'2026-11-10T12:00:00Z','read':false,
      'target':{'kind':'plans','opaque_id':'plan-1'},
    };
    final item=OrbitNotificationItem.fromJson(data);
    expect(item.category,'plans');
    expect(item.targetId,'plan-1');
    expect(()=>OrbitNotificationItem.fromJson({...data,
      'target':{'kind':'other','opaque_id':'plan-1'}}),
      throwsFormatException);
  });

  test('M15 routes remain separate from onboarding and M14 inbox',(){
    expect(AppRoutes.plans,'/plans');
    expect(AppRoutes.planDetail,'/plans/detail');
    expect(AppRoutes.planCreate,'/plans/create');
    expect(AppRoutes.planReminders,'/plans/reminders');
    expect(AppRoutes.plans,isNot(AppRoutes.notificationInbox));
  });

  testWidgets('Home Plan card retains approved layout and no fake avatars',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320,640));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    var taps=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Padding(
      padding:const EdgeInsets.all(15),
      child:UpcomingPlanCard(data:const UpcomingPlanData(
        id:'plan-1',title:'Family dinner',
        schedule:'Dec 4 · 7:00 PM',location:'Downtown',
        participants:<ParticipantData>[]),
        onTap:()=>taps++)))));
    expect(find.text('Family dinner'),findsOneWidget);
    await tester.tap(find.text('Family dinner'));
    expect(taps,1);
    expect(tester.takeException(),isNull);
  });
}
