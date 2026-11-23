import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/sos/data/orbit_sos_repository.dart';

Map<String,dynamic> sosRecord({String id='incident-1',
    String status='active',bool acknowledged=false})=>{
  'id':id,'status':status,'my_role':'initiator','revision':1,
  'created_at':'2026-11-23T12:00:00Z','server_accepted':true,
  'responder_acknowledgements':acknowledged?1:0,
  'push_provider_accepted_jobs':0,
  'in_app_available_for_eligible_responders':true,
  'location_sharing_active':false,
  'recording_consented':false,'recording_active':false,
  'recipients':[{'user_id':'member-1','source':'trusted','state':'pending'}],
};
class FakeSosIdentity extends OrbitIdentityClient {
  String? currentOwner='owner-1';
  String? method,path;
  Map<String,Object?>? request;
  bool swap=false;
  Map<String,dynamic> Function(String,String,Map<String,Object?>?) handle=
      (_,__,___)=>{'data':sosRecord()};
  @override
  Future<String?> currentLocalSocialOwner() async=>currentOwner;
  @override
  Future<Map<String,dynamic>> socialRequest(String verb,String endpoint,{
      Map<String,Object?>? body,String? idempotencyKey}) async {
    method=verb;path=endpoint;request=body;
    final result=handle(verb,endpoint,body);
    if(swap)currentOwner='owner-2';
    return result;
  }
}
class FakeSosVault extends OrbitSosPendingVault {
  OrbitSosIntent? saved;
  @override
  Future<void> put(OrbitSosIntent data) async {saved=data;}
  @override
  Future<OrbitSosIntent?> read(String owner) async => saved?.owner==owner?saved:null;
  @override
  Future<void> clear() async {saved=null;}
}
void main(){
  test('M16 never mistakes provider acceptance for responder acknowledgement',(){
    final event=OrbitSosIncident.fromJson(sosRecord());
    expect(event.serverAccepted,true);
    expect(event.acknowledgements,0);
    expect(event.deliveryDescription,contains('push delivery not confirmed'));
    expect(event.recordingDescription,'Not recording');
    expect(()=>OrbitSosIncident.fromJson({...sosRecord(),'revision':'1'}),
      throwsFormatException);
  });
  test('M16 location coordinates are parsed only from authorized endpoint',(){
    final value=OrbitSosLocation.fromJson({
      'latitude':30.2,'longitude':71.4,'expires_at':'2026-11-23T13:00:00Z',
    });
    expect(value.longitude,71.4);
    expect(()=>OrbitSosLocation.fromJson({
      'latitude':99.0,'longitude':71.4,'expires_at':'2026-11-23T13:00:00Z',
    }),throwsFormatException);
    expect(OrbitSosIncident.fromJson(sosRecord()).locationActive,false);
  });
  test('M16 creation uses server contract and clears only confirmed pending',() async {
    final identity=FakeSosIdentity(),vault=FakeSosVault();
    final repo=OrbitSosRepository(identity:identity,vault:vault);
    final item=await repo.create(shareLocation:false,recordingConsent:false);
    expect(item.id,'incident-1');
    expect(identity.method,'POST');
    expect(identity.path,'/sos/incidents');
    expect(identity.request?['confirm_sos'],true);
    expect(identity.request?['share_location'],false);
    expect(identity.request!.containsKey('latitude'),false);
    expect(identity.request?['client_id'],isA<String>());
    expect(vault.saved,isNull);
  });
  test('M16 retry uses identical client ID; a timeout is NOT a sent receipt',() async {
    final identity=FakeSosIdentity(),vault=FakeSosVault();
    final repo=OrbitSosRepository(identity:identity,vault:vault);
    identity.handle=(_,__,___)=>throw OrbitIdentityException('Connection lost');
    await expectLater(repo.create(shareLocation:false,recordingConsent:false),
      throwsA(isA<OrbitIdentityException>()));
    final pending=vault.saved;
    expect(pending,isNotNull);
    final clientId=pending!.clientId;
    identity.handle=(_,__,___)=>{'data':sosRecord()};
    await repo.retry(pending);
    expect(identity.request?['client_id'],clientId);
    expect(vault.saved,isNull);
  });
  test('M16 stale private coordinates are never replayed to backend',() async {
    final identity=FakeSosIdentity(),vault=FakeSosVault();
    final repo=OrbitSosRepository(identity:identity,vault:vault);
    final intent=OrbitSosIntent(owner:'owner-1',clientId:'request-1',
      createdAt:DateTime.now(),body:{'client_id':'request-1','confirm_sos':true,
        'share_location':true,'latitude':30.2,'longitude':71.4,
        'location_captured_at':DateTime.now().subtract(const Duration(minutes:4))
          .toUtc().toIso8601String()});
    await expectLater(repo.retry(intent),throwsStateError);
    expect(identity.method,isNull);
  });
  test('M16 account switch invalidates private server response',() async {
    final identity=FakeSosIdentity();identity.swap=true;
    final repo=OrbitSosRepository(identity:identity);
    await expectLater(repo.incident('incident-1'),
      throwsA(isA<OrbitIdentityException>()));
  });
  test('M16 contact decisions and scoped incident action routes',() async {
    final identity=FakeSosIdentity();
    final repo=OrbitSosRepository(identity:identity);
    identity.handle=(_,__,___)=>{'data':[{
      'id':'contact-1','owner_id':'owner-1','recipient_id':'friend-1',
      'state':'accepted',
    }]};
    await repo.decideContact('contact-1','accepted');
    expect(identity.path,'/sos/trusted-contacts/contact-1/decision');
    expect(identity.request?['state'],'accepted');
    identity.handle=(_,__,___)=>{'data':sosRecord()};
    await repo.cancel('incident-1',1);
    expect(identity.path,'/sos/incidents/incident-1/cancel');
    expect(identity.request?['revision'],1);
    await repo.acknowledge('incident-1');
    expect(identity.path,'/sos/incidents/incident-1/acknowledge');
  });
  test('M16 SOS routes are private and separate from onboarding',(){
    expect(AppRoutes.sos,'/sos');
    expect(AppRoutes.sosInbox,'/sos/inbox');
    expect(AppRoutes.sos,isNot(AppRoutes.shareLocation));
  });
}
