import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';

/// A server-registered incident, not evidence of delivery to a responder.
class OrbitSosIncident {
  const OrbitSosIncident({required this.id, required this.status,
    required this.revision, required this.role, required this.createdAt,
    required this.serverAccepted, required this.responders,
    required this.acknowledgements, required this.pushAccepted,
    required this.inAppAvailable, required this.locationActive,
    required this.recordingConsented, required this.recordingActive,
    this.myResponse});

  final String id, status, role;
  final int revision, acknowledgements, pushAccepted;
  final DateTime createdAt;
  final bool serverAccepted, inAppAvailable, locationActive;
  final bool recordingConsented, recordingActive;
  final String? myResponse;
  final List<OrbitSosResponder> responders;

  static OrbitSosIncident fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final status = data['status'];
    final revision = data['revision'];
    if (id is! String || id.isEmpty ||
        status is! String || revision is! num) {
      throw const FormatException('Invalid SOS incident response.');
    }
    final raw = data['recipients'];
    final people = raw is List ? raw.map((item) => OrbitSosResponder.fromJson(
      Map<String, dynamic>.from(item as Map))).toList(growable: false)
        : <OrbitSosResponder>[];
    return OrbitSosIncident(
      id: id, status: status, revision: revision.toInt(),
      role: data['my_role'] == 'responder' ? 'responder' : 'initiator',
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '')
          ?? DateTime.fromMillisecondsSinceEpoch(0),
      serverAccepted: data['server_accepted'] == true,
      responders: people,
      acknowledgements: (data['responder_acknowledgements'] as num?)?.toInt() ?? 0,
      pushAccepted: (data['push_provider_accepted_jobs'] as num?)?.toInt() ?? 0,
      inAppAvailable: data['in_app_available_for_eligible_responders'] == true,
      locationActive: data['location_sharing_active'] == true,
      recordingConsented: data['recording_consented'] == true,
      recordingActive: data['recording_active'] == true,
      myResponse:data['my_response'] as String?,
    );
  }

  String get deliveryDescription {
    if (acknowledgements > 0) return '$acknowledgements responder(s) acknowledged';
    if (pushAccepted > 0) return 'Push accepted by provider; no responder acknowledgement yet';
    if (inAppAvailable) return 'Available in Orbit; push delivery not confirmed';
    return 'No eligible responder confirmed. Contact emergency services directly.';
  }

  String get recordingDescription => recordingActive
      ? 'Recording status confirmed' : recordingConsented
      ? 'Consent saved; audio recording is not running'
      : 'Not recording';
}

class OrbitSosResponder {
  const OrbitSosResponder({required this.id, required this.source,
    required this.state});
  final String id, source, state;
  factory OrbitSosResponder.fromJson(Map<String,dynamic> data) =>
      OrbitSosResponder(id:data['user_id'] as String,
        source:data['source'] as String? ?? 'trusted',
        state:data['state'] as String? ?? 'pending');
}

class OrbitSosContact {
  const OrbitSosContact({required this.id, required this.ownerId,
    required this.recipientId, required this.state});
  final String id, ownerId, recipientId, state;
  factory OrbitSosContact.fromJson(Map<String,dynamic> json) =>
    OrbitSosContact(id:json['id'] as String, ownerId:json['owner_id'] as String,
      recipientId:json['recipient_id'] as String,
      state:json['state'] as String? ?? 'requested');
}

class OrbitSosLocation {
  const OrbitSosLocation({required this.latitude, required this.longitude,
    required this.expiresAt});
  final double latitude, longitude;
  final DateTime expiresAt;
  factory OrbitSosLocation.fromJson(Map<String,dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    final until=DateTime.tryParse(json['expires_at'] as String? ?? '');
    if(lat is! num || lng is! num || until == null ||
        lat.abs()>90 || lng.abs()>180) {
      throw const FormatException('Invalid SOS location.');
    }
    return OrbitSosLocation(latitude:lat.toDouble(),
      longitude:lng.toDouble(),expiresAt:until);
  }
}

class OrbitSosCapabilities {
  const OrbitSosCapabilities({required this.enabled,required this.pushReady,
    required this.inApp,required this.offlineRelay});
  final bool enabled,pushReady,inApp,offlineRelay;
  factory OrbitSosCapabilities.fromJson(Map<String,dynamic> data) =>
    OrbitSosCapabilities(enabled:data['server_intake_available']==true,
      pushReady:data['push_provider_ready']==true,
      inApp:data['in_app_responder_polling_available']==true,
      offlineRelay:data['offline_relay_available']==true);
}

/// One fully specified SOS POST for idempotent, user-initiated retries.
/// Coordinates are never stored in analytics or regular app preferences.
class OrbitSosIntent {
  const OrbitSosIntent({required this.owner,required this.clientId,
    required this.createdAt,required this.body});
  final String owner,clientId;
  final DateTime createdAt;
  final Map<String,Object?> body;
  bool get locationFresh {
    if(body['share_location']!=true)return true;
    final capture=DateTime.tryParse(body['location_captured_at'] as String? ?? '');
    return capture!=null && DateTime.now().toUtc()
      .difference(capture.toUtc()).inSeconds.abs()<=100;
  }
  Map<String,Object?> toJson()=>{'owner':owner,'client_id':clientId,
    'created_at':createdAt.toUtc().toIso8601String(),'body':body};
  factory OrbitSosIntent.fromJson(Map<String,dynamic> map) => OrbitSosIntent(
    owner:map['owner'] as String,clientId:map['client_id'] as String,
    createdAt:DateTime.parse(map['created_at'] as String),
    body:Map<String,Object?>.from(map['body'] as Map));
}

/// Short-lived OS-keystore encrypted uncertainty record. No automated sending,
/// background location, offline Relay assertion, or device-local delivery claim.
class OrbitSosPendingVault {
  OrbitSosPendingVault({FlutterSecureStorage? storage})
      : _storage=storage??const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const key='orbit.sos.pending.v1';
  static const maxAge=Duration(minutes:10);
  Future<void> put(OrbitSosIntent intent) => _storage.write(
    key:key,value:jsonEncode(intent.toJson()));
  Future<OrbitSosIntent?> read(String owner) async {
    final raw=await _storage.read(key:key);
    if(raw==null)return null;
    try {
      final decoded=OrbitSosIntent.fromJson(
        Map<String,dynamic>.from(jsonDecode(raw) as Map));
      final age=DateTime.now().toUtc().difference(decoded.createdAt.toUtc());
      if(decoded.owner==owner && age>=Duration.zero && age<=maxAge)return decoded;
    }catch(_){}
    await clear();
    return null;
  }
  Future<void> clear()=>_storage.delete(key:key);
}

class OrbitSosRepository {
  OrbitSosRepository({OrbitIdentityClient? identity, OrbitSosPendingVault? vault})
    : _identity=identity??OrbitIdentityClient.instance,
      _vault=vault??OrbitSosPendingVault();
  final OrbitIdentityClient _identity;
  final OrbitSosPendingVault _vault;
  static const Uuid _uuid=Uuid();

  Future<String> owner() async {
    final id=await _identity.currentLocalSocialOwner();
    if(id==null || id.isEmpty)throw OrbitIdentityException('Sign in to use SOS.',401);
    return id;
  }

  Future<Map<String,dynamic>> _call(String method,String path,
      {Map<String,Object?>? body}) async {
    final actor=await owner();
    final response=await _identity.socialRequest(method,path,body:body);
    if(await _identity.currentLocalSocialOwner()!=actor) {
      throw OrbitIdentityException('Your Orbit account has changed.',401);
    }
    return response;
  }
  Future<Map<String,dynamic>> _data(String method,String path,
      {Map<String,Object?>? body}) async {
    final raw=(await _call(method,path,body:body))['data'];
    if(raw is! Map)throw const FormatException('Invalid SOS service response.');
    return Map<String,dynamic>.from(raw);
  }
  Future<OrbitSosCapabilities> capabilities() async=>
    OrbitSosCapabilities.fromJson(await _data('GET','/sos/capabilities'));
  Future<List<OrbitSosIncident>> incidents() async {
    final raw=(await _call('GET','/sos/incidents?limit=40'))['data'];
    if(raw is! List)throw const FormatException('Invalid SOS history.');
    return raw.map((e)=>OrbitSosIncident.fromJson(
      Map<String,dynamic>.from(e as Map))).toList(growable:false);
  }
  Future<OrbitSosIncident> incident(String id) async=>OrbitSosIncident.fromJson(
    await _data('GET','/sos/incidents/${Uri.encodeComponent(id)}'));
  Future<OrbitSosLocation?> location(String id) async {
    try {
      return OrbitSosLocation.fromJson(await _data('GET',
        '/sos/incidents/${Uri.encodeComponent(id)}/location'));
    } on OrbitIdentityException catch(e) {
      if(e.statusCode==404)return null; // Expired, revoked or never shared.
      rethrow;
    }
  }
  Future<OrbitSosIncident> acknowledge(String id) async=>OrbitSosIncident.fromJson(
    await _data('POST','/sos/incidents/${Uri.encodeComponent(id)}/acknowledge'));
  Future<OrbitSosIncident> resolve(String id,int revision) async=>OrbitSosIncident.fromJson(
    await _data('POST','/sos/incidents/${Uri.encodeComponent(id)}/resolve',
      body:{'revision':revision}));
  Future<OrbitSosIncident> cancel(String id,int revision) async=>OrbitSosIncident.fromJson(
    await _data('POST','/sos/incidents/${Uri.encodeComponent(id)}/cancel',
      body:{'revision':revision}));
  Future<List<OrbitSosContact>> contacts() async {
    final raw=(await _call('GET','/sos/trusted-contacts'))['data'];
    return _parseContacts(raw);
  }
  List<OrbitSosContact> _parseContacts(Object? raw) {
    if(raw is! List)throw const FormatException('Invalid trusted contacts.');
    return raw.map((row)=>OrbitSosContact.fromJson(
      Map<String,dynamic>.from(row as Map))).toList(growable:false);
  }
  Future<List<OrbitSosContact>> addContact(String friendId) async=>_parseContacts(
    (await _call('POST','/sos/trusted-contacts',body:{'recipient_user_id':friendId}))['data']);
  Future<List<OrbitSosContact>> decideContact(String id,String state) async=>_parseContacts(
    (await _call('POST','/sos/trusted-contacts/${Uri.encodeComponent(id)}/decision',
      body:{'state':state}))['data']);
  Future<void> removeContact(String id) async {
    await _data('DELETE','/sos/trusted-contacts/${Uri.encodeComponent(id)}');
  }

  Future<OrbitSosIntent?> pending() async=>_vault.read(await owner());
  Future<void> discardPending() async=>_vault.clear();
  Future<OrbitSosIncident> create({String? circleId,required bool shareLocation,
    required bool recordingConsent,double? latitude,double? longitude,
    DateTime? capturedAt}) async {
    if(shareLocation && (latitude==null||longitude==null||capturedAt==null)) {
      throw ArgumentError('Location consent requires a fresh sample.');
    }
    final actor=await owner();
    final id=_uuid.v4();
    final request=<String,Object?>{
      'client_id':id,'confirm_sos':true,
      'share_location':shareLocation,'recording_consent':recordingConsent,
      if(circleId!=null)'circle_id':circleId,
      if(shareLocation)...{
        'latitude':latitude,'longitude':longitude,
        'location_captured_at':capturedAt!.toUtc().toIso8601String(),
      },
    };
    final intent=OrbitSosIntent(owner:actor,clientId:id,
      createdAt:DateTime.now().toUtc(),body:request);
    // Save before transmit, since a timeout can occur after the server commits.
    await _vault.put(intent);
    return retry(intent);
  }
  Future<OrbitSosIncident> retry(OrbitSosIntent intent) async {
    if(await owner()!=intent.owner)throw OrbitIdentityException('Account changed.',401);
    if(!intent.locationFresh){
      throw StateError('The prior location sample expired. Review SOS history before starting another alert.');
    }
    final result=OrbitSosIncident.fromJson(await _data('POST','/sos/incidents',body:intent.body));
    if(!result.serverAccepted)throw const FormatException('SOS was not confirmed by server.');
    // A verified server response must not be downgraded to "not sent" merely
    // because local encrypted-vault cleanup temporarily failed.
    try{await _vault.clear();}catch(_){}
    return result;
  }
}
