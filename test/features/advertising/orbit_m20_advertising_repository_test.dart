import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/advertising/data/orbit_advertising_repository.dart';

const adId='a0000000-0000-4000-8000-000000000001';

class FakeAdvertisingIdentity extends OrbitIdentityClient {
  String? owner='member-a';
  bool disabled=false;
  bool switchAfter=false;
  bool missing=false;
  bool corrupt=false;
  int assetCalls=0,decisions=0;
  final List<String> paths=[];
  final List<Map<String,Object?>?> bodies=[];

  Map<String,dynamic> capabilities()=>{
    'data':{
      'available':!disabled,
      'placements':{'home.promo':!disabled,'moments.promo':!disabled},
      'minimum_visible_ms':disabled?null:1200,
      'measurement_mode':'signed_receipt','schema_version':1,
    }
  };
  Map<String,dynamic>? decisionOverride;
  Map<String,dynamic> decision()=>decisionOverride??{
    'data':{
      'decision_id':adId,
      'placement':'home.promo',
      'creative':{
        'title':'Sponsored launch',
        'subtitle':'Approved creative description',
        'image_url':'https://indigo-caribou-178970.hostingersite.com/api/v1/ads/creatives/$adId/asset?decision=$adId&expires=9999999999&signature=abc',
        'disclosure':'Sponsored',
      },
      'cta':{'destination_url':'https://example.com/promo'},
      'expires_at':'2099-11-24 13:30:00',
      'measurement_token':'signed.m20.measurement.v1',
    }
  };

  @override
  Future<String?> currentLocalSocialOwner() async=>owner;

  @override
  Future<Map<String,dynamic>> socialRequest(String method,String path,
      {Map<String,Object?>? body,String? idempotencyKey}) async {
    paths.add(method+' '+path);
    bodies.add(body);
    if(missing)throw OrbitIdentityException('M20 not yet deployed.',404);
    final Map<String,dynamic> response;
    if(path=='/ads/capabilities'){
      expect(method,'GET');
      response=capabilities();
    }else if(path=='/ads/decisions'){
      expect(method,'POST');
      decisions++;
      response=decision();
      final d=response['data'];
      if(d is Map){
        final values=Map<String,dynamic>.from(d);
        values['placement']=body?['placement'];
        response['data']=values;
      }
    }else if(path=='/ads/measurements'){
      expect(method,'POST');
      response={'data':{'accepted':true,'deduplicated':false}};
    }else{
      throw StateError('Unknown test endpoint '+path);
    }
    if(switchAfter)owner='member-b';
    return response;
  }

  @override
  Future<Uint8List> advertisingAsset(String signedUrl,{
    int maxBytes=4*1024*1024,bool retry=true}) async {
    assetCalls++;
    if(corrupt)return Uint8List.fromList([137,80,78,71,13,10,26,10]);
    return base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGNMMRJhYGBgYmBgYGBgAAAIcgCu4vJ88AAAAABJRU5ErkJggg==');
  }
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Corrupt creative is rejected before any measurement',() async {
    final id=FakeAdvertisingIdentity()..corrupt=true;
    await expectLater(OrbitAdvertisingRepository(identity:id).load(OrbitAdvertisingRepository.homePlacement),throwsFormatException);
    expect(id.paths.where((p)=>p.endsWith('/ads/measurements')),isEmpty);
  });
  test('M20 disabled and missing backend never fabricate a sponsor',() async {
    final identity=FakeAdvertisingIdentity()..disabled=true;
    final repo=OrbitAdvertisingRepository(identity:identity);
    expect(await repo.load(OrbitAdvertisingRepository.homePlacement),isNull);
    expect(identity.decisions,0);
    identity.disabled=false;
    identity.missing=true;
    await expectLater(repo.load(OrbitAdvertisingRepository.homePlacement),
      throwsA(isA<OrbitIdentityException>()
        .having((e)=>e.statusCode,'status',404)));
    expect(identity.assetCalls,0);
  });

  test('M20 verified decision is owner-bound and reuses idempotency token',() async {
    final identity=FakeAdvertisingIdentity();
    final repo=OrbitAdvertisingRepository(identity:identity);
    final first=await repo.load(OrbitAdvertisingRepository.homePlacement);
    expect(first,isNotNull);
    expect(first!.id,adId);
    expect(first.minimumVisibleMs,1200);
    expect(first.title,'Sponsored launch');
    expect(first.destination.scheme,'https');
    expect(identity.assetCalls,1);
    expect(identity.decisions,1);
    final second=await repo.load(OrbitAdvertisingRepository.homePlacement,
      previous:first);
    expect(second,isNotNull);
    expect(second!.requestId,first.requestId);
    expect(identical(second.imageBytes,first.imageBytes),true);
    expect(identity.assetCalls,1);
    expect(identity.decisions,2);
    expect(identity.bodies[1]!['request_id'],identity.bodies[3]!['request_id']);
  });

  test('M20 no measurement before real exposure; click is separate',() async {
    final identity=FakeAdvertisingIdentity();
    final repo=OrbitAdvertisingRepository(identity:identity);
    final item=(await repo.load(OrbitAdvertisingRepository.homePlacement))!;
    expect(identity.paths.where((p)=>p.endsWith('/ads/measurements')),isEmpty);
    expect(await repo.impression(item,500),false);
    expect(identity.paths.where((p)=>p.endsWith('/ads/measurements')),isEmpty);
    expect(await repo.impression(item,1350),true);
    expect(identity.bodies.last!['event_type'],'impression');
    expect((identity.bodies.last!['evidence'] as Map)['visible_duration_ms'],1350);
    expect(await repo.click(item),true);
    expect(identity.bodies.last!['event_type'],'click');
    expect(identity.bodies.last!.containsKey('evidence'),false);
  });

  test('M20 owner changes fail closed before accepting decisions',() async {
    final identity=FakeAdvertisingIdentity()..switchAfter=true;
    final repo=OrbitAdvertisingRepository(identity:identity);
    await expectLater(repo.load(OrbitAdvertisingRepository.homePlacement),
      throwsA(isA<OrbitIdentityException>()
        .having((e)=>e.statusCode,'status',409)));
    expect(identity.assetCalls,0);
  });

  test('M20 rejects unsafe target, schema, expired and unknown placement',() async {
    final identity=FakeAdvertisingIdentity();
    final repo=OrbitAdvertisingRepository(identity:identity);
    await expectLater(repo.load('private.messages'),throwsArgumentError);
    expect(identity.paths,isEmpty);
    identity.decisionOverride=identity.decision();
    (identity.decisionOverride!['data'] as Map)['cta']={
      'destination_url':'javascript:alert(1)',
    };
    await expectLater(repo.load(OrbitAdvertisingRepository.homePlacement),
      throwsFormatException);
    identity.decisionOverride=identity.decision();
    (identity.decisionOverride!['data'] as Map)['expires_at']='2020-01-01T00:00:00Z';
    await expectLater(repo.load(OrbitAdvertisingRepository.homePlacement),
      throwsFormatException);
    identity.decisionOverride=null;
    identity.disabled=true;
    expect(await repo.load(OrbitAdvertisingRepository.homePlacement),isNull);
    expect(identity.assetCalls,0);
  });

  test('M20 private assets reject other origins and untrusted routes',() async {
    final identity=OrbitIdentityClient();
    await expectLater(
      identity.advertisingAsset('https://evil.example/api/v1/ads/creatives/$adId/asset?decision=$adId&expires=111&signature=x'),
      throwsArgumentError);
    await expectLater(
      identity.advertisingAsset('https://indigo-caribou-178970.hostingersite.com/api/v1/media/download?decision=x'),
      throwsArgumentError);
  });
}
