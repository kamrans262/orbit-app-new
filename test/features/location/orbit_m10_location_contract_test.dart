import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/location/data/orbit_location_models.dart';
import 'package:orbit_ui/features/location/data/orbit_location_repository.dart';
import 'package:orbit_ui/features/location/data/orbit_m10_rollout.dart';

void main(){
  test('M10 foreground map is available in plain flutter run',(){
    expect(OrbitM10Rollout.enabled,true);
    expect(OrbitM10Rollout.mapConfigured,true);
    expect(OrbitM10Rollout.realtimeConfigured,false);
  });

  Map<String,dynamic> marker({String state='updated',int age=4,
    double latitude=31.582045,double longitude=74.329376})=> {
    'user_id':'person-uuid','latitude':latitude,'longitude':longitude,
    'precision':'approximate','observed_at':'2026-10-27T12:00:00Z',
    'age_seconds':age,'state':state,
  };

  test('only validated authorized nonstale location pins survive decoding',(){
    final fresh=OrbitLocationMapSnapshot.fromJson({
      'markers':[marker(),marker()], 'server_time':'2026-10-27T12:00:03Z',
      'realtime_available':false,'live_claimed':false,
    });
    expect(fresh.markers.length,1);
    expect(fresh.markers.single.freshness,contains('Updated'));
    expect(fresh.realtimeAvailable,false);
    expect(OrbitLocationMapSnapshot.fromJson({
      'markers':[marker(age:121)],'server_time':'2026-10-27T12:00:03Z',
      'realtime_available':false,
    }).markers,isEmpty);
    expect(()=>OrbitLocationMarker.fromJson(marker(latitude:900)),throwsFormatException);
    expect(()=>OrbitLocationMarker.fromJson(marker(state:'live')),throwsFormatException);
    expect(()=>OrbitLocationMapSnapshot.fromJson({
      'markers':[marker()], 'server_time':'2026-10-27T12:00:03Z',
      'live_claimed':true,
    }),throwsFormatException);
  });

  test('privacy must be explicitly opt-in and Ghost is a global veto',(){
    final denied=OrbitLocationPrivacy.fromJson({});
    expect(denied.canShare,false);
    final on=OrbitLocationPrivacy.fromJson({
      'ghost':false,'sharing':true,'visibility':'Friends','activity':'Active'});
    expect(on.canShare,true);
    expect(OrbitLocationPrivacy.fromJson({
      'ghost':true,'sharing':true,'visibility':'Friends','activity':'Active'}).canShare,false);
  });

  test('no sample or share can be sent without explicit API selection',()async{
    final calls=<String>[],bodies=<Map<String,Object?>>[];
    final repo=OrbitLocationRepository(request:(method,path,{body})async{
      calls.add(method+' '+path);
      if(body!=null)bodies.add(body);
      if(path=='/location/capabilities')return {'data':{
        'global':{'ghost':false,'sharing':true,'activity':'Active','visibility':'Friends'},
        'latest_ttl_seconds':120,'until_leaving_available':false,
        'realtime_available':false,
      }};
      if(path=='/me/location/shares'&&method=='POST')return {'data':{
        'id':'grant-1','audience_type':'person','audience_id':'friend-1',
        'precision':'approximate','duration':'one_hour','status':'active'}};
      if(path=='/me/location/shares'&&method=='DELETE')return {'data':{'revoked':1}};
      if(path=='/location/map')return {'data':{
        'markers':[],'server_time':'2026-10-27T12:00:00Z','live_claimed':false}};
      return {'data':{}};
    });
    final cap=await repo.capabilities();
    expect(cap.global.canShare,true);
    final map=await repo.map();
    expect(map.markers,isEmpty);
    expect(bodies,isEmpty);
    final share=await repo.create(audienceType:'person',audienceId:'friend-1',
      precision:'approximate',duration:'one_hour');
    expect(share.active,true);
    expect(bodies.single['reviewed'],true);
    expect(bodies.single.containsKey('latitude'),false);
    await repo.stopAll();
    expect(calls.last,'DELETE /me/location/shares');
    expect(()=>repo.create(audienceType:'public',audienceId:'stranger',
      precision:'precise',duration:'always'),throwsFormatException);
  });
}
