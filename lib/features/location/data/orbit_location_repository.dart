import '../../auth/data/orbit_identity_client.dart';
import 'orbit_location_models.dart';

/// Trusted-device Orbit API, never caches coordinates, grants or last seen.
class OrbitLocationRepository {
  OrbitLocationRepository({OrbitIdentityClient? identity,
    Future<Map<String,dynamic>> Function(String method,String path,{Map<String,Object?>? body})? request})
    :_request=request??(identity??OrbitIdentityClient.instance).socialRequest;
  final Future<Map<String,dynamic>> Function(String method,String path,{Map<String,Object?>? body}) _request;
  Future<Map<String,dynamic>> _data(String method,String path,{Map<String,Object?>? body}) async {
    final response=await _request(method,path,body:body),raw=response['data'];
    if(raw is! Map)throw const FormatException('Invalid M10 response.');
    return Map<String,dynamic>.from(raw);
  }
  Future<OrbitLocationCapabilities> capabilities()=>_data('GET','/location/capabilities')
    .then(OrbitLocationCapabilities.fromJson);
  Future<OrbitLocationMapSnapshot> map({String? circleId})=>
    _data('GET',circleId==null?'/location/map':'/location/map?circle_id='+Uri.encodeQueryComponent(circleId))
    .then(OrbitLocationMapSnapshot.fromJson);
  Future<List<OrbitLocationShare>> shares() async {
    final d=await _data('GET','/me/location/shares'),raw=d['shares'];
    if(raw is! List)throw const FormatException('Invalid M10 shares.');
    return List.unmodifiable(raw.map((x)=>OrbitLocationShare.fromJson(Map<String,dynamic>.from(x as Map))));
  }
  Future<OrbitLocationShare> create({required String audienceType,required String audienceId,
    required String precision,required String duration,String? timezone,int? exitRadius}) async {
    if(!['person','circle'].contains(audienceType)||!['precise','approximate'].contains(precision)||
      !['one_hour','until_tonight','manual','always','until_leaving'].contains(duration)){
      throw const FormatException('Invalid location sharing choices.');
    }
    return OrbitLocationShare.fromJson(await _data('POST','/me/location/shares',body:{
      'audience_type':audienceType,'audience_id':audienceId,
      'precision':precision,'duration':duration,'reviewed':true,
      if(timezone!=null)'timezone':timezone,if(exitRadius!=null)'exit_radius_m':exitRadius,
    }));
  }
  Future<Map<String,dynamic>> realtimeTicket() async {
    final d=await _data('POST','/location/realtime/ticket');
    final token=d['ticket'],url=d['url'];
    if(token is! String || token.length<40 ||
       url is! String || !url.startsWith('wss://')) {
      throw const FormatException('Unverified realtime subscription.');
    }
    return d;
  }
  Future<void> attachAvatar({required String shareId,
    required String mediaId,required String grantId}) async {
    await _data('POST','/me/location/shares/'+Uri.encodeComponent(shareId)+
      '/avatar-grant',body:{'media_id':mediaId,'grant_id':grantId});
  }

  Future<void> stopAll() async {await _data('DELETE','/me/location/shares');}
  Future<void> revoke(String id) async {
    await _data('DELETE','/me/location/shares/'+Uri.encodeComponent(id));
  }
  Future<bool> sample({required double latitude,required double longitude,
    required double accuracy,required DateTime observedAt,double? speed,double? heading}) async {
    final d=await _data('POST','/me/location/samples',body:{
      'latitude':latitude,'longitude':longitude,'accuracy_m':accuracy,
      'observed_at':observedAt.toUtc().toIso8601String(),
      if(heading!=null&&heading>=0&&heading<=360)'heading':heading,
      if(speed!=null&&speed>=0&&speed<=100)'speed_mps':speed,
    });
    return d['accepted']==true;
  }
}
