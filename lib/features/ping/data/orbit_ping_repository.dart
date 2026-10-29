import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';

enum OrbitPingSendState { accepted, queued }

class OrbitPingRecord {
  const OrbitPingRecord({required this.id, required this.senderId,
    required this.recipientId, required this.type, required this.status,
    this.customText, this.contextType = 'friend', this.contextId});
  final String id, senderId, recipientId, type, status, contextType;
  final String? customText, contextId;
  factory OrbitPingRecord.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Invalid Ping service response.');
      }
      return value;
    }
    final context = json['context'];
    final ctx = context is Map ? Map<String, dynamic>.from(context) : <String, dynamic>{};
    return OrbitPingRecord(id: field('id'), senderId: field('sender_id'),
      recipientId: field('recipient_id'), type: field('type'),
      status: field('status'), customText: json['custom_text'] as String?,
      contextType: ctx['type'] as String? ?? 'friend',
      contextId: ctx['id'] as String?);
  }
  String get displayText => type == 'custom' ? (customText ?? 'Custom Ping') :
    const <String, String>{'hello':'👋 Hello', 'where':'📍 Where are you?',
      'on-my-way':"🚗 I'm on my way", 'right-there':'⏰ Be right there',
      'love':'❤️ Love you', 'call':'📞 Call me'}[type] ?? 'Ping';
}

class OrbitPingPage {
  const OrbitPingPage(this.items, this.nextCursor);
  final List<OrbitPingRecord> items;
  final String? nextCursor;
}

class OrbitPingPending {
  const OrbitPingPending({required this.clientId,required this.recipientId,
    required this.type,required this.contextType,this.contextId,this.customText});
  final String clientId,recipientId,type,contextType;
  final String? contextId,customText;
  Map<String,Object?> toJson() => {
    'client_id':clientId,'recipient_id':recipientId,
    'context':{'type':contextType,if(contextId!=null)'id':contextId},
    'type':type,if(customText!=null)'custom_text':customText,
  };
  factory OrbitPingPending.fromJson(Map<String,dynamic> data) {
    final ctx=Map<String,dynamic>.from(data['context'] as Map);
    return OrbitPingPending(clientId:data['client_id'] as String,
      recipientId:data['recipient_id'] as String,type:data['type'] as String,
      contextType:ctx['type'] as String,contextId:ctx['id'] as String?,
      customText:data['custom_text'] as String?);
  }
}

class OrbitPingRepository {
  OrbitPingRepository({OrbitIdentityClient? identity,FlutterSecureStorage? storage})
      : _identity=identity??OrbitIdentityClient.instance,
        _storage=storage??const FlutterSecureStorage();
  final OrbitIdentityClient _identity;
  final FlutterSecureStorage _storage;
  static const _prefix='orbit.ping.pending.v1.';
  static const _uuid=Uuid();
  Future<void>? _replay;
  Future<String> _owner() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null||owner.isEmpty)throw OrbitIdentityException('Sign in to Ping.',401);
    return owner;
  }
  Future<Map<String,dynamic>> _request(String method,String path,
      {Map<String,Object?>? body}) async {
    final response=await _identity.socialRequest(method,path,body:body);
    final data=response['data'];
    if(data is! Map)throw const FormatException('Invalid Ping service response.');
    return Map<String,dynamic>.from(data);
  }
  Future<bool> available() async =>
      (await _request('GET','/pings/capabilities'))['available']==true;
  Future<List<OrbitPingPending>> _read(String owner) async {
    try {
      final saved=await _storage.read(key:'$_prefix$owner');
      if(saved==null)return [];
      final value=jsonDecode(saved);
      if(value is! List)return [];
      return value.map((e)=>OrbitPingPending.fromJson(
        Map<String,dynamic>.from(e as Map))).take(25).toList();
    }catch(_){return [];}
  }
  Future<void> _write(String owner,List<OrbitPingPending> values) async {
    if(await _identity.currentLocalSocialOwner()!=owner)return;
    if(values.isEmpty){await _storage.delete(key:'$_prefix$owner');return;}
    await _storage.write(key:'$_prefix$owner',
      value:jsonEncode(values.map((v)=>v.toJson()).toList()));
  }
  Future<void> purge(String owner) => _storage.delete(key:'$_prefix$owner');
  bool _retryable(Object error) => error is OrbitIdentityException &&
      (error.statusCode==null || error.statusCode==408 || error.statusCode==429 || error.statusCode!>=500);

  /// Do not signal Delivered on an HTTP 201: only a recipient receipt can do that.
  /// Write a stable client ID to OS secure storage before attempting the POST.
  Future<OrbitPingSendState> send({required String recipientId,
    required String type,required String contextType,
    String? contextId,String? customText}) async {
    final owner=await _owner();
    if(recipientId==owner)throw ArgumentError('You cannot Ping yourself.');
    if(!const {'hello','where','on-my-way','right-there','love','call','custom'}
        .contains(type))throw ArgumentError('Unsupported Ping type.');
    if(contextType!='friend'&&contextType!='circle')throw ArgumentError('Invalid context.');
    if(contextType=='circle'&&(contextId==null||contextId.isEmpty)) {
      throw ArgumentError('Select a Circle.');
    }
    final message=customText?.trim();
    if(type=='custom'&&(message==null||message.isEmpty||message.runes.length>160)) {
      throw ArgumentError('Custom Ping must be 1–160 characters.');
    }
    await flushPending();
    final pending=await _read(owner);
    if(pending.length>=25)throw OrbitIdentityException('Pending Ping limit reached.',429);
    final intent=OrbitPingPending(clientId:_uuid.v4(),
      recipientId:recipientId,type:type,contextType:contextType,
      contextId:contextType=='circle'?contextId:null,
      customText:type=='custom'?message:null);
    pending.add(intent);
    await _write(owner,pending);
    try {
      await _request('POST','/pings',body:intent.toJson());
      final current=await _read(owner);
      current.removeWhere((v)=>v.clientId==intent.clientId);
      await _write(owner,current);
      return OrbitPingSendState.accepted;
    }catch(error){
      if(_retryable(error))return OrbitPingSendState.queued;
      final current=await _read(owner);
      current.removeWhere((v)=>v.clientId==intent.clientId);
      await _write(owner,current);
      rethrow;
    }
  }
  Future<void> flushPending() async {
    final inFlight=_replay;
    if(inFlight!=null){await inFlight;return;}
    final operation=_flush();
    _replay=operation;
    try{await operation;}finally{_replay=null;}
  }
  Future<void> _flush() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)return;
    final pending=await _read(owner);
    for(final intent in pending.toList()){
      if(await _identity.currentLocalSocialOwner()!=owner)return;
      try{
        await _request('POST','/pings',body:intent.toJson());
        pending.removeWhere((v)=>v.clientId==intent.clientId);
      }catch(error){
        if(_retryable(error))break;
        pending.removeWhere((v)=>v.clientId==intent.clientId);
      }
      await _write(owner,pending);
    }
  }
  Future<bool> circleConsent(String circle) async {
    final data=await _request('GET',
      '/me/pings/circles/'+Uri.encodeComponent(circle)+'/consent');
    return data['enabled']==true;
  }

  Future<bool> setCircleConsent(String circle,bool enabled) async {
    final data=await _request('PUT',
      '/me/pings/circles/'+Uri.encodeComponent(circle)+'/consent',
      body:{'enabled':enabled, if(enabled)'confirm':true});
    return data['enabled']==true;
  }

  Future<OrbitPingPage> page(String direction,{String? cursor}) async {
    if(direction!='inbox'&&direction!='outbox')throw ArgumentError.value(direction);
    final q=cursor==null?'':'?cursor='+Uri.encodeQueryComponent(cursor);
    final data=await _request('GET','/pings/$direction$q');
    final values=data['items'];
    if(values is! List)throw const FormatException('Invalid Ping inbox.');
    return OrbitPingPage(values.map((e)=>OrbitPingRecord.fromJson(
      Map<String,dynamic>.from(e as Map))).toList(growable:false),
      data['next_cursor'] as String?);
  }
  Future<void> receipt(String id,String kind) async {
    if(kind!='delivered'&&kind!='seen')throw ArgumentError.value(kind);
    await _request('POST','/pings/'+Uri.encodeComponent(id)+'/$kind');
  }
  Future<void> replyHey(String id,{String? clientId}) async {
    await _request('POST','/pings/'+Uri.encodeComponent(id)+'/respond',
      body:{'type':'hey','client_reply_id':clientId??_uuid.v4()});
  }
}
