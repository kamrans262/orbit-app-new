import '../../auth/data/orbit_identity_client.dart';
import 'orbit_messaging_models.dart';

/// Reuses trusted Orbit bearer auth/refresh; every response is server-scoped.
/// Never passes plaintext, raw private keys or local file paths to Laravel.
class OrbitMessagingApi {
  OrbitMessagingApi({OrbitIdentityClient? identity})
      : _identity=identity??OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;
  Future<String> get owner async {
    final id=await _identity.currentLocalSocialOwner();
    if(id==null||id.isEmpty)throw OrbitIdentityException('Sign in to open Messages.',401);
    return id;
  }
  String segment(String id)=>Uri.encodeComponent(id);
  Future<Map<String,dynamic>> request(String method,String path,
      {Map<String,Object?>? body}) async {
    if(!path.startsWith('/')||path.startsWith('//')||
        path.contains('..')||path.contains('://'))throw ArgumentError.value(path,'path');
    await owner;
    final response=await _identity.socialRequest(method,path,body:body);
    if(response['data'] is! Map)throw const FormatException('Invalid messaging response.');
    return Map<String,dynamic>.from(response['data'] as Map);
  }
  Future<OrbitMessagingCapabilities> capabilities() async =>
    OrbitMessagingCapabilities.fromJson(await request('GET','/messaging/capabilities'));
  Future<OrbitConversationPage> conversations({int page=1}) async =>
    OrbitConversationPage.fromJson(await request('GET','/conversations?page=$page'));
  Future<OrbitConversation> direct(String peer) async =>
    OrbitConversation.fromJson(await request('POST','/conversations/direct',
      body:{'recipient_id':peer}));
  Future<OrbitConversation> circle(String id) async =>
    OrbitConversation.fromJson(await request('GET',
      '/circles/'+segment(id)+'/messages/conversation'));
  Future<Map<String,dynamic>> myDevices()=>request('GET','/me/messaging/devices');
  Future<Map<String,dynamic>> registerKeys(OrbitMessagingPublicKeyBundle bundle)=>
    request('POST','/me/messaging/keys',body:bundle.toJson());
  /// Lookups used to authenticate an already-received ciphertext never
  /// consume an X3DH one-time prekey. Only session initiation may claim one.
  Future<OrbitMessagingKeyDirectory> discoverKeys(String user,
      {bool consumeOneTimePrekey=true}) async =>
    OrbitMessagingKeyDirectory.fromJson(await request('GET',
      '/messaging/keys/'+segment(user)+
      (consumeOneTimePrekey?'':'?claim_one_time_prekey=0')));
  Future<OrbitEnvelopePage> envelopes(String conversation,{
    String? cursor,int limit=50}) async {
    final params=Uri(queryParameters:{
      'limit':'$limit',if(cursor!=null)'cursor':cursor,
    }).query;
    return OrbitEnvelopePage.fromJson(await request('GET',
      '/conversations/'+segment(conversation)+'/envelopes?'+params));
  }
  Future<OrbitEnvelopePage> sync(String conversation,{
    List<String> delivered=const [],int limit=100}) async =>
    OrbitEnvelopePage.fromJson(await request('POST',
      '/conversations/'+segment(conversation)+'/sync',body:{
        'delivered_envelope_ids':delivered,'limit':limit,
      }));
  Future<OrbitMessageAccepted> publish(String conversation,{
    required String clientId,required String kind,required String protocol,
    required int groupEpoch,required List<OrbitCipherEnvelope> envelopes,
  }) async=>OrbitMessageAccepted.fromJson(await request('POST',
      '/conversations/'+segment(conversation)+'/envelopes',body:{
        'client_id':clientId,'kind':kind,'protocol':protocol,
        'group_epoch':groupEpoch,
        'envelopes':envelopes.map((e)=>e.toJson()).toList(),
      }));
  Future<void> delivered(String conversation,String id) async {
    await request('POST','/conversations/'+segment(conversation)+
      '/envelopes/'+segment(id)+'/delivered');
  }
  Future<void> read(String conversation,String id,Duration visible) async {
    if(visible.inMilliseconds<600)throw ArgumentError('Visible dwell too short.');
    await request('POST','/conversations/'+segment(conversation)+
      '/envelopes/'+segment(id)+'/read',body:{
        'visible_dwell_ms':visible.inMilliseconds,
      });
  }
  Future<Map<String,dynamic>> receipts(String conversation,String message)=>
    request('GET','/conversations/'+segment(conversation)+
      '/messages/'+segment(message)+'/receipts');
  Future<Map<String,dynamic>> consent(String circle)=>
    request('GET','/me/messaging/circles/'+segment(circle)+'/consent');
  Future<Map<String,dynamic>> setConsent(String circle,bool enabled)=>
    request('PUT','/me/messaging/circles/'+segment(circle)+'/consent',
      body:{'enabled':enabled,if(enabled)'confirm':true});
  Future<Map<String,dynamic>> typing(String conversation,bool active)=>
    request('POST','/conversations/'+segment(conversation)+'/typing',
      body:{'active':active});
  Future<Map<String,dynamic>> typingNow(String conversation)=>
    request('GET','/conversations/'+segment(conversation)+'/typing');
  Future<Map<String,dynamic>> setCircleTyping(String circle,bool enabled)=>
    request('PUT','/me/messaging/circles/'+segment(circle)+'/typing',
      body:{'enabled':enabled});
  Future<Map<String,dynamic>> preferences(String conversation,{
    bool? mute,bool? archive})=>
    request('PUT','/conversations/'+segment(conversation)+'/preferences',
      body:{if(mute!=null)'mute':mute,if(archive!=null)'archive':archive});
  Future<Map<String,dynamic>> report(String conversation,{
    required String reason,String? message,
    String? sharedEvidence,bool confirmed=false}) =>
    request('POST','/conversations/'+segment(conversation)+'/reports',
      body:{'reason':reason,if(message!=null)'message_id':message,
        if(sharedEvidence!=null)...{
          'share_evidence':true,'confirm_evidence_share':confirmed,
          'evidence_text':sharedEvidence,
        }});
  Future<Map<String,dynamic>> leave(String conversation)=>
    request('POST','/conversations/'+segment(conversation)+'/leave');
  Future<void> redact(String conversation,String message) async {
    await request('DELETE','/conversations/'+segment(conversation)+
      '/messages/'+segment(message));
  }
}
