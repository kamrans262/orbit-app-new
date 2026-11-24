import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:uuid/uuid.dart';
import '../../auth/data/orbit_identity_client.dart';

class OrbitSponsoredDecision {
  const OrbitSponsoredDecision({
    required this.id,required this.placement,required this.owner,
    required this.requestId,required this.title,required this.subtitle,
    required this.destination,required this.expiresAt,
    required this.measurementToken,required this.minimumVisibleMs,
    required this.imageBytes,
  });
  final String id,placement,owner,requestId,title,subtitle;
  final Uri destination;
  final DateTime expiresAt;
  final String measurementToken;
  final int minimumVisibleMs;
  final Uint8List imageBytes;
  bool get expired=>!DateTime.now().toUtc().isBefore(expiresAt);
  bool sameAuthorization(OrbitSponsoredDecision? other)=>other!=null &&
    id==other.id && owner==other.owner && placement==other.placement &&
    measurementToken==other.measurementToken && destination==other.destination &&
    minimumVisibleMs==other.minimumVisibleMs && expiresAt==other.expiresAt;
}

/// Foreground-only trusted-device advertising: no disk cache or member profile.
class OrbitAdvertisingRepository {
  OrbitAdvertisingRepository({OrbitIdentityClient? identity})
    :_identity=identity??OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;
  static const homePlacement='home.promo',momentsPlacement='moments.promo';
  static final RegExp _uuid=RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive:false);
  static bool validId(Object? s)=>s is String&&_uuid.hasMatch(s);

  Future<String> _owner() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null||owner.isEmpty)throw OrbitIdentityException(
      'Sign in to view sponsorships.',401);
    return owner;
  }

  Future<Map<String,dynamic>?> _data(String method,String path,String owner,
      {Map<String,Object?>? body}) async {
    final response=await _identity.socialRequest(method,path,body:body);
    if(await _identity.currentLocalSocialOwner()!=owner)throw OrbitIdentityException(
      'Account changed during sponsorship request.',409);
    final raw=response['data'];
    if(raw==null)return null;
    if(raw is! Map)throw const FormatException('Invalid sponsorship envelope.');
    return Map<String,dynamic>.from(raw);
  }

  Future<OrbitSponsoredDecision?> load(String placement,
      {OrbitSponsoredDecision? previous}) async {
    if(placement!=homePlacement&&placement!=momentsPlacement)
      throw ArgumentError.value(placement,'placement');
    final owner=await _owner();
    final caps=await _data('GET','/ads/capabilities',owner);
    if(caps==null||caps['available']!=true)return null;
    final slots=caps['placements'];
    if(slots is! Map||slots[placement]!=true)return null;
    final threshold=caps['minimum_visible_ms'];
    if(threshold is! int||threshold<1||threshold>300000||
       caps['measurement_mode']!='signed_receipt'||caps['schema_version']!=1)
      throw const FormatException('Sponsored viewability policy unverified.');
    // Same idempotency UUID until expiry: no 25-second Home refresh cap burn.
    final reusable=previous!=null&&previous.owner==owner&&
      previous.placement==placement&&!previous.expired;
    final requestId=reusable?previous.requestId:const Uuid().v4();
    final entry=await _data('POST','/ads/decisions',owner,body:{
      'placement':placement,'request_id':requestId,
    });
    if(entry==null)return null;
    final id=entry['decision_id'],creative=entry['creative'],cta=entry['cta'];
    final token=entry['measurement_token'],time=entry['expires_at'];
    if(!validId(id)||entry['placement']!=placement||creative is! Map||
       cta is! Map||creative['disclosure']!='Sponsored'||
       creative['title'] is! String||creative['subtitle'] is! String||
       creative['image_url'] is! String||token is! String||
       token.length<12||token.length>400||time is! String)
      throw const FormatException('Invalid sponsorship decision.');
    final rawTimestamp=RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(time)
        ?time:time+'Z';
    final expires=DateTime.tryParse(rawTimestamp)?.toUtc();
    final target=cta['destination_url'];
    final url=target is String?Uri.tryParse(target):null;
    if(expires==null||!expires.isAfter(DateTime.now().toUtc())||
       url==null||url.scheme!='https'||url.host.isEmpty||
       url.userInfo.isNotEmpty||url.hasPort||url.hasFragment||
       url.host=='localhost'||url.host.contains('..'))
      throw const FormatException('Unsafe sponsored destination.');
    final imageUrl=creative['image_url'] as String;
    final priorBytes=reusable&&previous.id==id&&!previous.expired
        ?previous.imageBytes:null;
    final bytes=priorBytes??await _identity.advertisingAsset(imageUrl);
    if(await _identity.currentLocalSocialOwner()!=owner)
      throw OrbitIdentityException('Account changed during ad image load.',409);
    if(bytes.isEmpty||bytes.length>4*1024*1024)
      throw const FormatException('Invalid sponsored image.');
    // Decode the actual creative before making it eligible for measurement.
    // Header-only or corrupt bytes must never render a measurable fallback.
    if(priorBytes==null){
      ui.ImmutableBuffer? buffer;
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      ui.Image? image;
      try{
        buffer=await ui.ImmutableBuffer.fromUint8List(bytes);
        descriptor=await ui.ImageDescriptor.encoded(buffer);
        if(descriptor.width<1||descriptor.height<1||
           descriptor.width>4096||descriptor.height>4096)
          throw const FormatException('Invalid creative dimensions.');
        codec=await descriptor.instantiateCodec();
        if(codec.frameCount!=1)throw const FormatException('Animated creative unsupported.');
        image=(await codec.getNextFrame()).image;
      }catch(_){
        throw const FormatException('Invalid sponsored image.');
      }finally{
        image?.dispose();codec?.dispose();descriptor?.dispose();buffer?.dispose();
      }
    }
    if(await _identity.currentLocalSocialOwner()!=owner || !expires.isAfter(DateTime.now().toUtc()))
      throw OrbitIdentityException('Sponsorship authorization expired or changed.',409);
    return OrbitSponsoredDecision(id:id as String,placement:placement,
      owner:owner,requestId:requestId,title:creative['title'] as String,
      subtitle:creative['subtitle'] as String,destination:url,
      expiresAt:expires,measurementToken:token,
      minimumVisibleMs:threshold,imageBytes:bytes);
  }

  Future<bool> impression(OrbitSponsoredDecision ad,int visibleMs) async {
    if(ad.expired||visibleMs<ad.minimumVisibleMs)return false;
    if(await _owner()!=ad.owner)return false;
    final result=await _data('POST','/ads/measurements',ad.owner,body:{
      'decision_id':ad.id,'event_type':'impression',
      'client_event_id':const Uuid().v4(),
      'measurement_token':ad.measurementToken,
      'evidence':{'visible_duration_ms':visibleMs.clamp(0,300000)},
    });
    return !ad.expired && result?['accepted']==true;
  }

  Future<bool> click(OrbitSponsoredDecision ad) async {
    if(ad.expired||await _owner()!=ad.owner)return false;
    final result=await _data('POST','/ads/measurements',ad.owner,body:{
      'decision_id':ad.id,'event_type':'click',
      'client_event_id':const Uuid().v4(),
      'measurement_token':ad.measurementToken,
    });
    return !ad.expired && result?['accepted']==true;
  }
}
