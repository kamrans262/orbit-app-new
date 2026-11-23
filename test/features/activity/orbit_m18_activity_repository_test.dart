import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/activity/data/orbit_activity_repository.dart';

const eventId='a0000000-0000-4000-8000-000000000001';
const momentId='b0000000-0000-4000-8000-000000000002';
const checkInId='c0000000-0000-4000-8000-000000000003';

Map<String,dynamic> event({String source='check_in',
  String sourceId=checkInId})=>{
    'id':eventId,
    'kind':source=='moment'?'moment.published':'check_in.published',
    'source':{'type':source,'id':sourceId},
    'source_revision':1,'occurred_at':'2026-11-24 08:14:22',
  };

class FakeActivityIdentity extends OrbitIdentityClient {
  String? owner='account-a';
  bool switchOnResponse=false;
  final List<String> paths=[];
  Map<String,dynamic> Function(String) handle=(path){
    if(path=='/activity/capabilities')return {'data':{
      'available':true,'sources':{'moment':true,'check_in':true},
      'sync_mode':'authoritative_refresh','realtime_available':false,
    }};
    if(path=='/activity/changes')return {'data':{
      'items':[],'invalidated_ids':[],'reset_required':true,
      'sync_mode':'authoritative_refresh',
    }};
    if(path.startsWith('/activity/feed?'))return {'data':{
      'items':[event()],'next_cursor':null,
      'sync_mode':'authoritative_refresh',
    }};
    return {'data':event(source:'moment',sourceId:momentId)};
  };
  @override
  Future<String?> currentLocalSocialOwner() async=>owner;
  @override
  Future<Map<String,dynamic>> socialRequest(String method,String path,{
    Map<String,Object?>? body,String? idempotencyKey}) async {
    expect(method,'GET');
    paths.add(path);
    final response=handle(path);
    if(switchOnResponse)owner='account-b';
    return response;
  }
}

void main(){
  test('M18 strict typed pointers reject unknown private sources',(){
    final checkIn=OrbitActivityItem.fromJson(event());
    expect(checkIn.sourceType,'check_in');
    expect(checkIn.occurredAt.isUtc,true);
    final moment=OrbitActivityItem.fromJson(
      event(source:'moment',sourceId:momentId));
    expect(moment.kind,'moment.published');
    expect(()=>OrbitActivityItem.fromJson({
      ...event(),'kind':'message.available',
    }),throwsFormatException);
    expect(()=>OrbitActivityItem.fromJson({
      ...event(),'source':{'type':'sos','id':checkInId},
    }),throwsFormatException);
    expect(()=>OrbitActivityItem.fromJson({
      ...event(),'source':{'type':'check_in','id':'bad'},
    }),throwsFormatException);
    expect(()=>OrbitActivityItem.fromJson({
      ...event(),'source_revision':0,
    }),throwsFormatException);
  });
  test('M18 handshake and private endpoints use existing session',() async {
    final client=FakeActivityIdentity();
    final repo=OrbitActivityRepository(identity:client);
    final c=await repo.capabilities();
    expect(c.available,true);
    expect(c.checkIns,true);
    expect(await repo.requiresRefresh(),true);
    expect(client.paths,['/activity/capabilities','/activity/changes']);
    client.handle=(_)=>{'data':{
      'reset_required':false,'sync_mode':'incremental',
    }};
    await expectLater(repo.requiresRefresh(),throwsFormatException);
  });
  test('M18 signed cursor is passed to original server, owner switches reject',() async {
    final client=FakeActivityIdentity();
    final repo=OrbitActivityRepository(identity:client);
    await repo.page(limit:3,cursor:'signed.cursor');
    expect(client.paths.single,'/activity/feed?limit=3&cursor=signed.cursor');
    await expectLater(repo.page(limit:31),throwsArgumentError);
    client.switchOnResponse=true;
    await expectLater(repo.page(),throwsA(isA<OrbitIdentityException>()
      .having((e)=>e.statusCode,'status',409)));
  });
  test('M18 signed-out and malformed responses fail closed',() async {
    final client=FakeActivityIdentity();
    final repo=OrbitActivityRepository(identity:client);
    client.owner=null;
    await expectLater(repo.page(),throwsA(isA<OrbitIdentityException>()));
    expect(client.paths,isEmpty);
    client.owner='account-a';
    client.handle=(_)=>{'data':[]};
    await expectLater(repo.page(),throwsFormatException);
    await expectLater(repo.item('bad'),throwsArgumentError);
  });
  test('M18 bounded pagination deduplicates repeated pointers',() async {
    final client=FakeActivityIdentity();
    var calls=0;
    client.handle=(_){
      calls++;
      return {'data':{'items':[event()],'next_cursor':'signed.same',
        'sync_mode':'authoritative_refresh'}};
    };
    final entries=await OrbitActivityRepository(identity:client)
      .currentPointers(maximum:20);
    expect(entries,hasLength(1));
    expect(calls,2);
    expect(()=>entries.clear(),throwsUnsupportedError);
  });
  test('M18 rejects corrupt timestamp and excess page data',(){
    expect(()=>OrbitActivityItem.fromJson({
      ...event(),'occurred_at':'invalid',
    }),throwsFormatException);
    expect(()=>OrbitActivityPage.fromJson({
      'items':[event(source:'ping')],'next_cursor':null,
      'sync_mode':'authoritative_refresh',
    }),throwsFormatException);
    expect(()=>OrbitActivityPage.fromJson({
      'items':List.filled(31,event()),'next_cursor':null,
      'sync_mode':'authoritative_refresh',
    }),throwsFormatException);
  });
}
