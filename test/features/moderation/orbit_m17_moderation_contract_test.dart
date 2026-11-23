import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/moderation/data/orbit_moderation_repository.dart';
import 'package:orbit_ui/features/profile/domain/models/report_user_models.dart';

class FakeModerationIdentity extends OrbitIdentityClient {
  String? currentOwner='owner-one';
  final List<Map<String,Object?>> calls=[];
  Map<String,dynamic> Function(String,String,Map<String,Object?>?) handle=
      (_,path,__)=>path=='/me/moderation/reports'
          ?{'data':<Object>[]}
          :{'data':{'id':'report-123','status':'received',
              'created_at':'2026-11-24T01:00:00Z'}};
  bool changeAccount=false;

  @override
  Future<String?> currentLocalSocialOwner() async=>currentOwner;

  @override
  Future<Map<String,dynamic>> socialRequest(String method,String path,{
      Map<String,Object?>? body,String? idempotencyKey}) async {
    calls.add({'method':method,'path':path,'body':body});
    final response=handle(method,path,body);
    if(changeAccount)currentOwner='owner-two';
    return response;
  }
}

class FakeModerationVault extends OrbitModerationPendingVault {
  final Map<String,OrbitModerationIntent> values={};
  @override
  Future<void> put(OrbitModerationIntent item) async {
    values[item.kind]=item;
  }
  @override
  Future<OrbitModerationIntent?> read(String owner,String kind) async {
    final item=values[kind];
    return item?.owner==owner?item:null;
  }
  @override
  Future<void> clear(String kind) async {values.remove(kind);}
  @override
  Future<void> clearAll() async {values.clear();}
}

void main() {
  test('M17 report request uses exact account API and server receipt',() async {
    final identity=FakeModerationIdentity(),vault=FakeModerationVault();
    final repo=OrbitModerationRepository(identity:identity,pending:vault);
    const request=ReportRequest(
      reportedUserId:'target-user',reason:ReportReason.harassment,
    );
    final receipt=await repo.submitReport(request);
    expect(receipt.id,'report-123');
    expect(receipt.status,'received');
    expect(identity.calls.single['method'],'POST');
    expect(identity.calls.single['path'],'/moderation/reports');
    final body=identity.calls.single['body'] as Map<String,Object?>;
    expect(body['target_kind'],'account');
    expect(body['target_id'],'target-user');
    expect(body['reason'],'harassment');
    expect(body['client_id'],isA<String>());
    expect(body.containsKey('reported_user_id'),false);
    expect(body.containsKey('additional_details'),false);
    expect(vault.values,isEmpty);
    expect(ReportReason.inappropriateContent.apiValue,'inappropriate_content');
    expect(ReportReason.spam.apiValue,'spam');
    expect(ReportReason.other.apiValue,'other');
  });

  test('M17 timeout cannot claim success; user retry uses identical UUID',() async {
    final identity=FakeModerationIdentity(),vault=FakeModerationVault();
    final repo=OrbitModerationRepository(identity:identity,pending:vault);
    const input=ReportRequest(
      reportedUserId:'target-user',reason:ReportReason.spam,
    );
    identity.handle=(_,__,___)=>throw OrbitIdentityException('Connection lost');
    await expectLater(repo.submitReport(input),throwsA(isA<OrbitIdentityException>()));
    final first=identity.calls.single['body'] as Map<String,Object?>;
    expect(vault.values['report']?.clientId,first['client_id']);
    identity.handle=(_,__,___)=>{
      'data':{'id':'report-original','status':'received',
        'created_at':'2026-11-24T01:00:00Z'},
    };
    final confirmed=await repo.submitReport(input);
    final retried=identity.calls.last['body'] as Map<String,Object?>;
    expect(retried['client_id'],first['client_id']);
    expect(confirmed.id,'report-original');
    expect(vault.values,isEmpty);
  });

  test('M17 changed details do not reuse uncertain payload identity',() async {
    final identity=FakeModerationIdentity(),vault=FakeModerationVault();
    final repo=OrbitModerationRepository(identity:identity,pending:vault);
    identity.handle=(_,__,___)=>throw OrbitIdentityException('Timeout');
    await expectLater(repo.submitReport(const ReportRequest(
      reportedUserId:'target-user',reason:ReportReason.spam,
    )),throwsA(isA<OrbitIdentityException>()));
    final first=vault.values['report']!.clientId;
    await expectLater(repo.submitReport(const ReportRequest(
      reportedUserId:'target-user',reason:ReportReason.other,
    )),throwsA(isA<OrbitIdentityException>()));
    expect(vault.values['report']!.clientId,isNot(first));
  });

  test('M17 definitive API denial clears pending without success',() async {
    final identity=FakeModerationIdentity(),vault=FakeModerationVault();
    identity.handle=(_,__,___)=>throw OrbitIdentityException('Not available',404);
    final repo=OrbitModerationRepository(identity:identity,pending:vault);
    await expectLater(repo.submitReport(const ReportRequest(
      reportedUserId:'target-user',reason:ReportReason.harassment,
    )),throwsA(isA<OrbitIdentityException>()));
    expect(vault.values,isEmpty);
  });

  test('M17 malformed response is not a created report',() async {
    final identity=FakeModerationIdentity(),vault=FakeModerationVault();
    identity.handle=(_,__,___)=>{'data':{'status':'received'}};
    final repo=OrbitModerationRepository(identity:identity,pending:vault);
    await expectLater(repo.submitReport(const ReportRequest(
      reportedUserId:'target-user',reason:ReportReason.harassment,
    )),throwsFormatException);
    expect(vault.values['report'],isNotNull);
  });

  test('M17 identity change invalidates response and clears sensitive intent',() async {
    final identity=FakeModerationIdentity(),vault=FakeModerationVault();
    identity.changeAccount=true;
    final repo=OrbitModerationRepository(identity:identity,pending:vault);
    await expectLater(repo.submitReport(const ReportRequest(
      reportedUserId:'target-user',reason:ReportReason.harassment,
    )),throwsA(isA<OrbitIdentityException>()));
    expect(identity.currentOwner,'owner-two');
    expect(vault.values,isEmpty);
  });

  test('M17 appeals are private, idempotent and require server confirmation',() async {
    final identity=FakeModerationIdentity(),vault=FakeModerationVault();
    final repo=OrbitModerationRepository(identity:identity,pending:vault);
    identity.handle=(_,__,___)=>throw OrbitIdentityException('Offline');
    await expectLater(repo.appeal('action-one'),
      throwsA(isA<OrbitIdentityException>()));
    final first=identity.calls.last['body'] as Map<String,Object?>;
    expect(identity.calls.last['path'],
      '/moderation/actions/action-one/appeals');
    expect(first.keys.toSet(),{'client_id'});
    expect(vault.values['appeal'],isNotNull);
    identity.handle=(_,__,___)=>{'data':{
      'id':'appeal-one','status':'pending','created_at':'2026-11-24T01:00:00Z',
    }};
    final result=await repo.appeal('action-one');
    expect(result.status,'pending');
    expect((identity.calls.last['body'] as Map<String,Object?>)['client_id'],
      first['client_id']);
    expect(vault.values,isEmpty);
  });

  test('M17 owned history is never mixed across account switch',() async {
    final identity=FakeModerationIdentity();
    final repo=OrbitModerationRepository(identity:identity,
        pending:FakeModerationVault());
    identity.handle=(method,path,body){
      if(path=='/me/moderation/reports')return {'data':[{
        'id':'r','status':'received','created_at':'2026-11-24T01:00:00Z',
      }]};
      if(path=='/me/moderation/actions')return {'data':[{
        'id':'a','scope':'messaging_send','status':'active',
        'created_at':'2026-11-24T01:00:00Z','ends_at':null,
      }]};
      if(path=='/me/moderation/appeals')return {'data':[{
        'id':'b','status':'upheld','created_at':'2026-11-24T01:00:00Z',
      }]};
      throw StateError('Unexpected API endpoint $path');
    };
    final snapshot=await repo.myHistory();
    expect(snapshot.reports.single.id,'r');
    expect(snapshot.actions.single.id,'a');
    expect(snapshot.appeals.single.status,'upheld');
    identity.changeAccount=true;
    await expectLater(repo.myHistory(),throwsA(isA<OrbitIdentityException>()));
  });

  test('M17 naive server timestamps are interpreted as UTC not local',(){
    final plain=orbitModerationUtcTimestamp('2024-01-02 00:00:00');
    final tagged=orbitModerationUtcTimestamp('2024-01-02T00:00:00Z');
    expect(plain,tagged);
    expect(plain?.isUtc,true);
    expect(plain?.toIso8601String(),'2024-01-02T00:00:00.000Z');
    expect(orbitModerationUtcTimestamp('invalid'),null);
    expect(orbitModerationUtcTimestamp(null),null);
  });

  test('M17 maps private appeal to its action and displays expired M13 block',(){
    final matching=OrbitModerationAppeal.fromJson({
      'id':'appeal-id','action_id':'action-id','status':'pending',
      'created_at':'2026-11-24T01:00:00Z',
    });
    expect(matching.actionId,'action-id');
    final expired=OrbitModerationAction.fromJson({
      'id':'action-id','scope':'messaging_send','status':'active',
      'created_at':'2024-01-01T00:00:00Z',
      'ends_at':'2024-01-02T00:00:00Z',
    });
    expect(expired.effectiveStatus,'expired');
    final indefinite=OrbitModerationAction.fromJson({
      'id':'action-id-2','scope':'messaging_send','status':'active',
      'created_at':'2024-01-01T00:00:00Z','ends_at':null,
    });
    expect(indefinite.effectiveStatus,'active');
    final warning=OrbitModerationAction.fromJson({
      'id':'action-id-3','scope':'warning','status':'reversed',
      'created_at':'2024-01-01T00:00:00Z',
    });
    expect(warning.effectiveStatus,'reversed');
  });

  test('M17 fails closed on fabricated appeal or action fields',(){
    expect(()=>OrbitModerationAppeal.fromJson({
      'id':'appeal','status':'resolved',
      'created_at':'2026-11-24T01:00:00Z',
    }),throwsFormatException);
    expect(()=>OrbitModerationAction.fromJson({
      'id':'action','scope':'account_access','status':'active',
      'created_at':'2026-11-24T01:00:00Z',
    }),throwsFormatException);
    expect(()=>OrbitModerationReceipt.fromJson({
      'id':'report','status':'investigating',
      'created_at':'2026-11-24T01:00:00Z',
    }),throwsFormatException);
  });
}
