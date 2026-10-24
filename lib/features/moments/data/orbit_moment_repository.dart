import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import '../../auth/data/orbit_identity_client.dart';
import '../../circles/data/orbit_circle_repository.dart';
import '../../media/data/orbit_media_crypto.dart';
import '../../media/data/orbit_media_recipient_keys.dart';
import '../../media/data/orbit_media_repository.dart';
import '../../media/data/orbit_moment_media_stager.dart';
import '../../media/data/orbit_encrypted_clip_stager.dart';
import '../domain/models/moment_publish_models.dart';
import 'orbit_moment_intent_vault.dart';
import 'orbit_moment_seen_vault.dart';
import '../../media/data/orbit_media_outbox.dart';

class OrbitLiveMoment {
  const OrbitLiveMoment({required this.id,required this.creatorId,
    required this.mediaId,required this.contextId,required this.publishedAt,
    this.captionCiphertext,this.mediaKind='image',this.durationMs,
    this.placeCiphertext,this.taggedUserIds=const [],
    this.publishVersion=1,this.audienceRevision=1});
  final String id, creatorId, mediaId, contextId;
  final DateTime publishedAt;
  final String? captionCiphertext;
  final String? placeCiphertext;
  final List<String> taggedUserIds;
  final String mediaKind;
  final int? durationMs;
  final int publishVersion,audienceRevision;
  factory OrbitLiveMoment.fromJson(Map<String,dynamic> d) =>
    OrbitLiveMoment(id:d['id'] as String,creatorId:d['creator_id'] as String,
      mediaId:d['media_id'] as String,contextId:d['context_id'] as String,
      publishedAt:DateTime.parse(d['published_at'] as String),
      captionCiphertext:d['caption_ciphertext'] as String?,
      placeCiphertext:d['place_ciphertext'] as String?,
      taggedUserIds:List<String>.from(d['tagged_user_ids'] as List? ?? const []),
      mediaKind:d['media_kind'] as String? ?? 'image',
      durationMs:(d['duration_ms'] as num?)?.toInt(),
      publishVersion:(d['publish_version'] as num?)?.toInt()??1,
      audienceRevision:(d['audience_revision'] as num?)?.toInt()??1);
}

class OrbitMomentAudienceOptions {
  const OrbitMomentAudienceOptions(this.circles,this.friends,this.privacy);
  final List<MomentAudienceCircle> circles,friends;
  final String privacy;
  bool get circlesEnabled => privacy=='My Circle';
  bool get friendsEnabled => privacy=='Selected People';
}

/// Uses only M4 trusted-device identity and M6 authenticated ciphertext API.
class OrbitMomentRepository {
  OrbitMomentRepository({OrbitIdentityClient? identity,OrbitMediaRepository? media,
    OrbitMomentMediaStager? stager,OrbitMediaRecipientKeys? recipientKeys,
    OrbitCircleRepository? circles,OrbitMediaCrypto? crypto,
    OrbitMomentIntentVault? intents,OrbitMomentSeenVault? seenVault})
    : _identity=identity??OrbitIdentityClient.instance,
      _media=media??OrbitMediaRepository(identity:identity),
      _stager=stager??OrbitMomentMediaStager(identity:identity),
      _keys=recipientKeys??OrbitMediaRecipientKeys(identity:identity),
      _circles=circles??OrbitCircleRepository(identity:identity),
      _crypto=crypto??OrbitMediaCrypto(),
      _intents=intents??OrbitMomentIntentVault(),
      _seenVault=seenVault??OrbitMomentSeenVault(
        owner:(identity??OrbitIdentityClient.instance).currentLocalSocialOwner);
  final OrbitIdentityClient _identity;
  final OrbitMediaRepository _media;
  final OrbitMomentMediaStager _stager;
  final OrbitMediaRecipientKeys _keys;
  final OrbitCircleRepository _circles;
  final OrbitMediaCrypto _crypto;
  final OrbitMomentIntentVault _intents;
  final OrbitMomentSeenVault _seenVault;
  static const Uuid _uuid=Uuid();
  // Track app-session native players; opening another Moment must not remove
  // a different still-playing clip. Files from crashed sessions are not in
  // this set and are evicted on the next authorized open.
  static final Set<String> _activePrivateClipPaths=<String>{};

  Future<Map<String,dynamic>> _api(String method,String path,
      {Map<String,Object?>? body,String? key}) async {
    final r=await _identity.socialRequest(method,path,body:body,
        idempotencyKey:key);
    final d=r['data'];
    if(d is! Map)throw const FormatException('Unexpected private Moments response.');
    return Map<String,dynamic>.from(d);
  }
  Future<List<OrbitLiveMoment>> feed({
    bool rail=false,String? circleId,String? profileId,int maxItems=120,
  }) async {
    if(circleId!=null && profileId!=null)throw ArgumentError('Choose one feed scope.');
    final root=rail?'/moments/rail':circleId!=null
      ? '/circles/${Uri.encodeComponent(circleId)}/moments'
      : profileId!=null?'/users/${Uri.encodeComponent(profileId)}/moments':'/moments';
    final result=<OrbitLiveMoment>[];
    final seen=<String>{};
    String? before,beforeId;
    for(var page=0;page<8 && result.length<maxItems;page++){
      final query=<String,String>{'limit':rail?'20':'30'};
      if(before!=null&&beforeId!=null){
        query['before']=before;query['before_id']=beforeId;
      }
      final response=await _api('GET',root+'?'+Uri(queryParameters:query).query);
      final raw=response['items'];
      if(raw is! List)throw const FormatException('Private Moments feed malformed.');
      for(final entry in raw){
        final moment=OrbitLiveMoment.fromJson(Map<String,dynamic>.from(entry as Map));
        if(seen.add(moment.id+'|'+moment.contextId))result.add(moment);
        if(result.length>=maxItems)break;
      }
      final cursor=response['next_cursor'];
      if(cursor is! Map||cursor['before'] is! String ||
         cursor['before_id'] is! String||raw.isEmpty)break;
      final nextBefore=cursor['before'] as String;
      final nextId=cursor['before_id'] as String;
      if(nextBefore==before&&nextId==beforeId)break;
      before=nextBefore;beforeId=nextId;
    }
    return result;
  }
  Future<OrbitMomentAudienceOptions> audienceOptions() async {
    final privacy=await _api('GET','/me/preferences/privacy');
    final audience=privacy['moment_default_audience'] as String? ?? 'Nobody';
    final friends=<MomentAudienceCircle>[];
    if(audience=='Selected People'){
      for(var page=1;page<=5;page++){
        final d=await _api('GET','/friends?page='+page.toString());
        final items=d['items'];
        if(items is! List)throw const FormatException('Friends response malformed.');
        for(final x in items){
          if(x is Map && x['id'] is String)friends.add(
            MomentAudienceCircle(id:x['id'] as String,
              name:x['display_name'] as String? ?? 'Orbit member'));
        }
        if(d['has_more']!=true)break;
        if(page==5)throw StateError('Please narrow your recipient selection.');
      }
    }
    final circles=<MomentAudienceCircle>[];
    if(audience=='My Circle'){
      for(var page=1;page<=5;page++){
        final d=await _circles.list(page:page);
        for(final x in d.items) {
          if(x.lifecycleState=='active'&&x.role!='restricted') {
            circles.add(MomentAudienceCircle(id:x.id,name:x.name));
          }
        }
        if(!d.hasMore)break;
        if(page==5)throw StateError('Too many Circles to enumerate safely.');
      }
    }
    return OrbitMomentAudienceOptions(circles,friends,audience);
  }
  Future<List<String>> _members(String circleId) async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)throw StateError('Not signed in.');
    final people=<String>{};
    for(var page=1;page<=10;page++){
      final d=await _circles.members(circleId,page:page);
      for(final m in d.items){
        if(m.id!=owner&&m.role!='restricted')people.add(m.id);
      }
      if(!d.hasMore)break;
      if(page==10)throw StateError('Circle exceeds safe recipient limit.');
    }
    return people.toList();
  }
  Future<List<Map<String,Object?>>> _envelopes(String audience,
      List<String> targets,OrbitSealedMedia original,OrbitSealedMedia? thumbnail) async {
    final result=<Map<String,Object?>>[];
    if(audience=='selected_circles'){
      final unique=<String>{};
      for(final circle in targets){
        final recipients=await _members(circle);
        if(recipients.isEmpty)continue;
        final people=await _keys.discover(audienceKind:'selected_circles',
            recipientIds:recipients,circleId:circle);
        for(final person in people)for(final device in person.devices){
          if(!unique.add(device.id))continue;
          final single=[OrbitMediaRecipient(person.userId,[device])];
          result.addAll(await _keys.encryptEnvelopes(original,single));
          if(thumbnail!=null)result.addAll(await _keys.encryptEnvelopes(thumbnail,single));
        }
      }
    }else{
      List<String> users=targets;
      if(audience=='accepted_friends'){
        final options=await audienceOptions();
        users=options.friends.map((f)=>f.id).toList();
      }
      if(users.isNotEmpty){
        final people=await _keys.discover(audienceKind:'selected_friends',recipientIds:users);
        result.addAll(await _keys.encryptEnvelopes(original,people));
        if(thumbnail!=null)result.addAll(await _keys.encryptEnvelopes(thumbnail,people));
      }
    }
    if(result.isEmpty||result.length>300) {
      throw StateError('No eligible trusted recipient device keys.');
    }
    return result;
  }
  Future<String> _sealText(String text,Uint8List key,String media,
    String purpose,String context) async {
    final nonce=_crypto.randomBytes(12);
    final box=await AesGcm.with256bits().encrypt(utf8.encode(text),
      secretKey:SecretKey(key),nonce:nonce,
      aad:utf8.encode('orbit-m7-'+purpose+'-v1|'+media+'|'+context));
    return 'v1.'+base64Encode(nonce)+'.'+base64Encode(box.cipherText)+
        '.'+base64Encode(box.mac.bytes);
  }
  Future<String> _openText(String cipher,Uint8List key,String media,
      String purpose,String context) async {
    final fields=cipher.split('.');
    if(fields.length!=4||fields[0]!='v1') {
      throw const FormatException('Unsupported encrypted text.');
    }
    final b=await AesGcm.with256bits().decrypt(
      SecretBox(base64Decode(fields[2]),nonce:base64Decode(fields[1]),
        mac:Mac(base64Decode(fields[3]))),secretKey:SecretKey(key),
      aad:utf8.encode('orbit-m7-'+purpose+'-v1|'+media+'|'+context));
    return utf8.decode(b);
  }
  Future<Uint8List> _key(String media) async {
    final d=await _identity.trustedMediaDevice();
    final path='/media/'+Uri.encodeComponent(media)+
      '/key-envelope?device_id='+Uri.encodeComponent(d.id)+'&variant=original';
    final envelope=await _media.control('GET',path);
    final material=await _crypto.unwrapKey(
      envelope['wrapped_key_ciphertext'] as String,
      privateKey:d.privateKey,publicKey:d.publicKey);
    return material.key;
  }
  Future<MomentPublishReceipt> publish(MomentPublishRequest request,
      void Function(double) progress) async {
    final audience=request.audienceKind;
    final targets=request.targetIds.toList();
    if(!['only_me','accepted_friends','selected_friends','selected_circles'].contains(audience))
      throw StateError('Invalid Moment audience.');
    if((audience=='selected_circles'||audience=='selected_friends')&&targets.isEmpty)
      throw StateError('Select an audience first.');
    final options=await audienceOptions();
    if(audience=='selected_circles'&&!options.circlesEnabled ||
        (audience=='selected_friends'||audience=='accepted_friends')&&!options.friendsEnabled) {
      throw StateError('Update Moment sharing in Privacy Settings first.');
    }
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)throw StateError('Sign in before publishing.');
    String? stagedTransfer;
    Future<void> queued(String transfer) async {
      stagedTransfer=transfer;
      await _intents.save(OrbitStoredMomentIntent(
        owner:owner,transfer:transfer,clientId:request.clientId,
        audienceKind:audience,targetIds:targets,caption:request.caption,
        placeLabel:request.placeLabel,
        locationConsent:request.locationConsent,
        taggedUserIds:request.taggedUserIds.toList(),
        createdAt:DateTime.now().toUtc()));
    }
    String? id;
    Future<void> commit(OrbitSealedMedia original,OrbitSealedMedia? derivative,
        String mediaId) async {
      final existing=await _existingReceipt(request.clientId);
      if(existing!=null){id=existing;return;}
      if(audience!='only_me'){
        final grants=await _media.createGrants(mediaId,
          audience:audience,recipients:targets,
          idempotencyKey:request.clientId,
          keyEnvelopes:await _envelopes(audience,targets,original,derivative));
        if(grants.isEmpty)throw StateError('Recipient grants unavailable.');
      }
      final caption=request.caption.trim().isEmpty?null:
        await _sealText(request.caption.trim(),original.key,mediaId,
          'caption','self');
      final place=request.locationConsent && request.placeLabel.trim().isNotEmpty?
        await _sealText(request.placeLabel.trim(),original.key,mediaId,'place','self'):null;
      progress(0.92);
      final result=await _api('POST','/moments',key:request.clientId,body:{
        'client_id':request.clientId,'media_id':mediaId,
        'audience_kind':audience,'target_ids':targets,
        if(caption!=null)'caption_ciphertext':caption,
        if(caption!=null)'caption_key_version':'v1',
        if(place!=null)'place_ciphertext':place,
        if(place!=null)'place_key_version':'v1',
        if(place!=null)'location_consent':true,
        'tagged_user_ids':request.taggedUserIds.toList(),
      });
      if(result['published']!=true||result['audience_keys_confirmed']!=true||
          result['moment_id'] is! String){
        throw StateError('Server did not confirm Moment publication.');
      }
      id=result['moment_id'] as String;
    }
    if(request.mediaKind=='image'){
      await _stager.stagePhoto(request.photoBytes,
        onProgress:(v)=>progress(v*0.82),
        onReadyForAudience:commit,onQueued:queued);
    }else{
      final source=request.mediaFile;
      if(source==null || !await source.exists()) {
        throw StateError('Captured clip is no longer available.');
      }
      final stager=OrbitEncryptedClipStager(identity:_identity,crypto:_crypto,
        media:_media);
      if(request.mediaKind=='video'){
        await stager.stageVideo(source,muteAudio:request.muteVideo,
          onProgress:(v)=>progress(v*0.82),
          onReadyForAudience:(video,poster,mediaId) async =>
            commit(video,poster,mediaId),onQueued:queued);
      }else if(request.mediaKind=='audio'){
        final duration=request.durationMs;
        if(duration==null || duration<1 || duration>60000){
          throw StateError('Voice Moments must be under 60 seconds.');
        }
        await stager.stageAudio(source,
          mime:'audio/mp4',durationMs:duration,purpose:'moment',
          waveformLevels:request.waveformLevels,
          onProgress:(v)=>progress(v*0.82),
          onReadyForAudience:(audio,waveform,mediaId) async =>
            commit(audio,waveform,mediaId),onQueued:queued);
      }else{
        throw StateError('Unsupported Moment media kind.');
      }
    }
    if(id==null)throw StateError('Moment not published.');
    if(stagedTransfer!=null)await _intents.remove(owner,stagedTransfer!);
    progress(1);
    return MomentPublishReceipt(momentId:id!);
  }
  /// A cached Moment UUID or decryption key is never an authorization token.
  /// Re-check the server context before keeping a decoded image on screen.
  Future<bool> remainsAuthorized(OrbitLiveMoment item) async {
    try {
      final data=await _api('GET',
        '/moments/${Uri.encodeComponent(item.id)}?context_id='
        '${Uri.encodeQueryComponent(item.contextId)}');
      return data['media_id']==item.mediaId &&
        data['context_id']==item.contextId &&
        data['id']==item.id;
    } catch (_) {
      return false; // Offline, revoked or expired: fail closed.
    }
  }

  Future<String?> _existingReceipt(String clientId) async {
    try{
      final d=await _api('GET','/moments/receipt/'+Uri.encodeComponent(clientId));
      if(d['published']!=true || d['audience_keys_confirmed']!=true){
        throw StateError('Moment receipt is not published.');
      }
      return d['moment_id'] as String;
    }on OrbitIdentityException catch(e){
      if(e.statusCode==404)return null;
      rethrow;
    }
  }

  /// Count only this signed-in account's protected publication intents.
  Future<int> pendingPublishCount() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)return 0;
    return (await _intents.pending(owner)).length;
  }

  /// User-initiated or foreground retry only. Never publish from a background
  /// worker, and do not treat encrypted upload success as Moment publication.
  Future<int> resumePendingPublishes({
    void Function(double progress)? onProgress,
    bool force=false,
  }) async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)return 0;
    final intents=await _intents.pending(owner);
    if(intents.isEmpty)return 0;
    var completed=0;
    final encryptedDrafts=await OrbitMediaOutbox().pending(owner);
    final transferIds=encryptedDrafts.where((d)=>d.variant=='original')
      .map((d)=>d.transfer).toSet();
    final eligible=<String,OrbitStoredMomentIntent>{};
    final now=DateTime.now().toUtc();
    for(final intent in intents){
      // A queued intent never extends the server's seven-day visibility TTL.
      // Old drafts require explicit review; never silently delete ciphertext.
      if(now.difference(intent.createdAt)>const Duration(days:7) && !force){
        continue;
      }
      if(!force && (intent.attemptCount>=8 ||
          (intent.retryAfter!=null && now.isBefore(intent.retryAfter!)))){
        continue;
      }
      final server=await _existingReceipt(intent.clientId);
      if(server!=null){
        for(final draft in encryptedDrafts.where((d)=>
            d.transfer==intent.transfer || d.parentTransferId==intent.transfer)){
          await OrbitMediaOutbox().discard(draft);
        }
        await _intents.remove(owner,intent.transfer);
        completed++;
      }else if(!transferIds.contains(intent.transfer)){
        throw StateError('Missing encrypted media: recapture is required.');
      }else{
        eligible[intent.transfer]=intent;
      }
    }
    await _stager.retryPending(onProgress:onProgress,
      shouldRetry:(parent)=>eligible.containsKey(parent.transfer),
      onRetryStart:(parent)=>
        _intents.markAttempt(owner,parent.transfer).then((_){ }),
      onRecovered:(transfer,original,derivative,mediaId) async {
        final intent=await _intents.read(owner,transfer);
        if(intent==null)return;
        final previous=await _existingReceipt(intent.clientId);
        if(previous!=null){
          await _intents.remove(owner,transfer);
          completed++;
          return;
        }
        final options=await audienceOptions();
        if(intent.audienceKind=='selected_circles'&&!options.circlesEnabled ||
           (intent.audienceKind=='selected_friends'||
            intent.audienceKind=='accepted_friends')&&!options.friendsEnabled){
          throw StateError('Audience privacy changed. Review the Moment draft.');
        }
        if(intent.audienceKind!='only_me'){
          final keys=await _envelopes(intent.audienceKind,intent.targetIds,
            original,derivative);
          final grants=await _media.createGrants(mediaId,
            audience:intent.audienceKind,recipients:intent.targetIds,
            idempotencyKey:_uuid.v4(),keyEnvelopes:keys);
          if(grants.isEmpty)throw StateError('Recipient key delivery failed.');
        }
        final cipher=intent.caption.trim().isEmpty?null:
          await _sealText(intent.caption.trim(),original.key,mediaId,
            'caption','self');
        final place=intent.locationConsent && intent.placeLabel.trim().isNotEmpty?
          await _sealText(intent.placeLabel.trim(),original.key,mediaId,'place','self'):null;
        final r=await _api('POST','/moments',key:intent.clientId,body:{
          'client_id':intent.clientId,'media_id':mediaId,
          'audience_kind':intent.audienceKind,'target_ids':intent.targetIds,
          if(cipher!=null)'caption_ciphertext':cipher,
          if(cipher!=null)'caption_key_version':'v1',
          if(place!=null)'place_ciphertext':place,
          if(place!=null)'place_key_version':'v1',
          if(place!=null)'location_consent':true,
          'tagged_user_ids':intent.taggedUserIds,
        });
        if(r['published']!=true||r['audience_keys_confirmed']!=true||
            r['moment_id'] is! String){
          throw StateError('Publication has not been confirmed.');
        }
        await _intents.remove(owner,transfer);
        completed++;
      });
    return completed;
  }

  Future<Uint8List> photo(OrbitLiveMoment item,{String variant='thumbnail'}) async {
    if(item.mediaKind=='audio' && variant=='original'){
      throw StateError('Voice audio is available through private playback only.');
    }
    final d=await _identity.trustedMediaDevice();
    final v=variant=='thumbnail' && item.mediaKind=='video'?'poster':
      (variant=='thumbnail' && item.mediaKind=='audio'?'waveform':variant);
    return _media.downloadPhoto(item.mediaId,deviceId:d.id,
      privateKey:d.privateKey,publicKey:d.publicKey,variant:v);
  }

  /// Native players receive only a temporary decrypted app-cache file. It is
  /// deleted when its viewer closes/backgrounds. No remote plaintext URL.
  Future<File> openPrivateClip(OrbitLiveMoment item) async {
    if(!['video','audio'].contains(item.mediaKind)) {
      throw StateError('This Moment is not playable media.');
    }
    if(!await remainsAuthorized(item)) {
      throw StateError('Moment access was revoked.');
    }
    final device=await _identity.trustedMediaDevice();
    const safeMax=64*1024*1024;
    final bytes=await _media.downloadPhoto(item.mediaId,
      deviceId:device.id,privateKey:device.privateKey,
      publicKey:device.publicKey,maxPlainBytes:safeMax);
    if(!await remainsAuthorized(item)) {
      bytes.fillRange(0,bytes.length,0);
      throw StateError('Moment access changed while decrypting.');
    }
    final dir=Directory('${(await getTemporaryDirectory()).path}/orbit-m7-playback');
    await dir.create(recursive:true);
    // Purge orphaned cleartext from a previous crashed session without
    // disrupting other currently-playing clips in this process.
    for(final entry in await dir.list().toList()){
      if(entry is File && !_activePrivateClipPaths.contains(entry.path)){
        try{await entry.delete();}catch(_){}
      }
    }
    final path='${dir.path}/${_uuid.v4()}.${item.mediaKind=='video'?'mp4':'m4a'}';
    final file=File(path);
    try{
      await file.writeAsBytes(bytes,flush:true);
      _activePrivateClipPaths.add(file.path);
      return file;
    }catch(_){
      // A failed write must not leave a partial playable plaintext artifact.
      try{if(await file.exists())await file.delete();}catch(_){}
      rethrow;
    }finally{
      bytes.fillRange(0,bytes.length,0);
    }
  }

  Future<void> erasePrivateClip(File? file) async {
    if(file==null)return;
    _activePrivateClipPaths.remove(file.path);
    try{if(await file.exists())await file.delete();}catch(_){}
  }
  Future<String?> caption(OrbitLiveMoment item) async {
    final encrypted=item.captionCiphertext;
    if(encrypted==null||encrypted.isEmpty)return null;
    return _openText(encrypted,await _key(item.mediaId),item.mediaId,
      'caption','self');
  }
  Future<String?> place(OrbitLiveMoment item) async {
    final cipher=item.placeCiphertext;
    if(cipher==null || cipher.isEmpty)return null;
    return _openText(cipher,await _key(item.mediaId),item.mediaId,
      'place','self');
  }

  Future<Set<String>> seenMomentIds(Iterable<String> ids) async {
    try{return await _seenVault.seenIds(ids);}
    catch(_){return <String>{};}
  }
  Future<void> view(OrbitLiveMoment item) async {
    await _api('POST','/moments/'+Uri.encodeComponent(item.id)+'/views',
      body:{'context_id':item.contextId});
    // Store only this viewer's local seen state; never disclose it in a feed.
    try{await _seenVault.markSeen(item.id);}catch(_){}
  }
  Future<void> react(OrbitLiveMoment item,{required bool liked}) async {
    final path='/moments/'+Uri.encodeComponent(item.id)+'/reaction';
    if(liked)await _api('PUT',path,
      body:{'context_id':item.contextId,'reaction_code':'like'});
    else await _identity.socialRequest('DELETE',path,
      body:{'context_id':item.contextId});
  }
  Future<List<({String id,String author,String body,String? parent})>>
      comments(OrbitLiveMoment item) async {
    final data=await _api('GET','/moments/'+Uri.encodeComponent(item.id)+
      '/comments?context_id='+Uri.encodeQueryComponent(item.contextId));
    final rows=data['items'];
    if(rows is! List)throw const FormatException('Invalid encrypted comments.');
    if(rows.isEmpty)return [];
    final key=await _key(item.mediaId);
    final values=<({String id,String author,String body,String? parent})>[];
    for(final raw in rows){
      final r=Map<String,dynamic>.from(raw as Map);
      values.add((id:r['id'] as String,author:r['author_id'] as String,
        body:await _openText(r['body_ciphertext'] as String,key,
          item.mediaId,'comment',item.contextId),
        parent:r['parent_id'] as String?));
    }
    return values;
  }
  Future<void> comment(OrbitLiveMoment item,String text,{String? parent}) async {
    await _api('POST','/moments/'+Uri.encodeComponent(item.id)+'/comments',
      key:_uuid.v4(),body:{
        'context_id':item.contextId,
        'body_ciphertext':await _sealText(text,await _key(item.mediaId),
          item.mediaId,'comment',item.contextId),
        'key_version':'v1',if(parent!=null)'parent_id':parent,
      });
  }
  Future<void> deleteComment(OrbitLiveMoment item,String commentId) async {
    await _identity.socialRequest('DELETE',
      '/moments/${Uri.encodeComponent(item.id)}/comments/${Uri.encodeComponent(commentId)}',
      body:{'context_id':item.contextId});
  }

  Future<List<Map<String,dynamic>>> authorizedViewers(OrbitLiveMoment item) async {
    final data=await _api('GET','/moments/${Uri.encodeComponent(item.id)}/viewers');
    final raw=data['viewers'];
    if(raw is! List)throw const FormatException('View receipts malformed.');
    return raw.map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }

  Future<List<({String id,String author,String body,String? parent})>>
      allComments(OrbitLiveMoment item,{int max=150}) async {
    final out=<({String id,String author,String body,String? parent})>[];
    final key=await _key(item.mediaId);
    String? before,beforeId;
    for(var page=0;page<6 && out.length<max;page++){
      final query=<String,String>{'context_id':item.contextId,'limit':'30'};
      if(before!=null && beforeId!=null){
        query['before']=before;
        query['before_id']=beforeId;
      }
      final data=await _api('GET',
        '/moments/${Uri.encodeComponent(item.id)}/comments?'
        +Uri(queryParameters:query).query);
      final raw=data['items'];
      if(raw is! List)throw const FormatException('Encrypted comments malformed.');
      for(final entry in raw){
        final r=Map<String,dynamic>.from(entry as Map);
        out.add((id:r['id'] as String,author:r['author_id'] as String,
          body:await _openText(r['body_ciphertext'] as String,key,
            item.mediaId,'comment',item.contextId),
          parent:r['parent_id'] as String?));
        if(out.length>=max)break;
      }
      final next=data['next_before'];
      final nextId=data['next_before_id'];
      if(next is! String||nextId is! String||raw.isEmpty||
         (next==before && nextId==beforeId))break;
      before=next;
      beforeId=nextId;
    }
    return out;
  }

  Future<void> report(OrbitLiveMoment item,String reason,
      {String? commentId,bool account=false}) async {
    final path='/moments/'+Uri.encodeComponent(item.id)+
      (commentId==null?'/reports':
        '/comments/'+Uri.encodeComponent(commentId)+'/reports');
    await _api('POST',path,key:_uuid.v4(),
      body:{'context_id':item.contextId,'reason':reason,
        'report_target':account?'account':
          commentId!=null?'comment':'moment',
        'evidence_consent':false});
  }
  /// UI owner controls are gated against the currently signed-in account;
  /// Laravel independently re-checks ownership before any sensitive action.
  Future<String?> currentUserId() => _identity.currentLocalSocialOwner();

  /// A caption edit changes only encrypted text, not keys, media or audience.
  /// Backend enforces creator ownership and optimistic publish_version.
  Future<int> updateCaption(OrbitLiveMoment item,String text) async {
    final owner=await currentUserId();
    if(owner==null || owner!=item.creatorId)throw StateError('Not the Moment owner.');
    final value=text.trim();
    if(value.length>200)throw const FormatException('Caption exceeds 200 characters.');
    final cipher=value.isEmpty?null:
      await _sealText(value,await _key(item.mediaId),item.mediaId,'caption','self');
    final response=await _api('PATCH','/moments/${Uri.encodeComponent(item.id)}',
      body:{'revision':item.publishVersion,
        'caption_ciphertext':cipher,
        'caption_key_version':cipher==null?null:'v1'});
    final revision=response['publish_version'];
    if(revision is! num || revision.toInt()<=item.publishVersion) {
      throw StateError('Caption revision was not confirmed.');
    }
    return revision.toInt();
  }

  Future<void> delete(OrbitLiveMoment item) async {
    await _api('DELETE','/moments/'+Uri.encodeComponent(item.id));
  }
  Future<String> name(String userId) async {
    if(await _identity.currentLocalSocialOwner()==userId)return 'You';
    final d=await _api('GET','/people/'+Uri.encodeComponent(userId)+'/preview');
    return d['display_name'] as String? ?? 'Orbit member';
  }
}
