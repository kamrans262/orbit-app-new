import '../../messaging/data/orbit_messaging_api.dart';

/// Existing authenticated HTTPS transport; no new token or public API.
class OrbitRelayApi {
  OrbitRelayApi({OrbitMessagingApi? messaging}):_api=messaging??OrbitMessagingApi();
  final OrbitMessagingApi _api;
  Future<String> get owner=>_api.owner;
  Future<Map<String,dynamic>> capabilities()=>_api.request('GET','/relay/capabilities');
  Future<Map<String,dynamic>> lease({required String scope,required String peer,
      required int keyVersion,required String nonce})=>_api.request('POST','/relay/leases',body:{
    'scope_ref':scope,'peer_device_ref':peer,'device_key_id':keyVersion,
    'client_nonce':nonce,'protocol_version':'orbit-relay-direct-v1','content_type':'direct_message',
  });
  Future<Map<String,dynamic>> revoke(String id,{String reason='cancel'})=>
      _api.request('POST','/relay/leases/'+Uri.encodeComponent(id)+'/revoke',body:{'reason':reason});
  Future<Map<String,dynamic>> reconcile(String batchId,List<Map<String,Object?>> items)=>
      _api.request('POST','/relay/reconcile',body:{'batch_id':batchId,'items':items});
  Future<Map<String,dynamic>> sync({String? cursor,int limit=20})=>_api.request('GET',
    '/relay/sync?'+Uri(queryParameters:{'limit':limit.clamp(1,100).toString(),
      if(cursor!=null)'cursor':cursor}).query);
}
