import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../circles/data/orbit_circle_repository.dart';
import 'orbit_messaging_api.dart';
import 'orbit_messaging_cipher.dart';
import 'orbit_messaging_local_vault.dart';
import 'orbit_messaging_models.dart';
import 'orbit_messaging_media_bridge.dart';
import 'orbit_messaging_reactions.dart';
import 'orbit_messaging_replies.dart';
import 'orbit_messaging_vodozemac_cipher.dart';

/// Authenticated account-bound messaging orchestration.
/// No E2EE fallback, no optimistic "sent", no plaintext HTTPS requests.
class OrbitMessagingCoordinator {
  OrbitMessagingCoordinator({OrbitMessagingApi? api,
    OrbitMessagingCipher? cipher,OrbitMessagingLocalVault? vault,
    OrbitCircleRepository? circles})
    : api=api??OrbitMessagingApi(),
      cipher=cipher??OrbitMessagingCipherRegistry.instance.active,
      vault=vault??OrbitMessagingLocalVault(),
      circles=circles??OrbitCircleRepository();

  final OrbitMessagingApi api;
  final OrbitMessagingCipher cipher;
  final OrbitMessagingLocalVault vault;
  final OrbitCircleRepository circles;

  // Account-scoped server cursors. Repeated foreground refreshes must not
  // reset the older-message paging position to the newest messages.
  final Map<String,String?> _olderCursors=<String,String?>{};
  final Map<String,Set<String>> _redactedByConversation={};

  Set<String> redactedMessageIds(String owner,String conversation)=>
    Set<String>.unmodifiable(
      _redactedByConversation[_pageKey(owner,conversation)]??<String>{});


  // Serialize all cryptographic work per owner across ALL active chat
  // coordinators in one process. Polling, session setup, send, and backfill
  // must not concurrently mutate the same device ratchet or sender-key state.
  static final Map<String,Future<void>> _mailboxLocks={};
  // For reviewed native builds, public identity registration is performed
  // once per account/device/key fingerprint. No demo or unreviewed provider
  // may generate or advertise keys as a side effect of opening Messages.
  static final Set<String> _registeredNativeIdentities=<String>{};
  Future<T> _serialMailbox<T>(String owner,String conversation,
      Future<T> Function() operation) async {
    final key=_pageKey(owner,conversation);
    final previous=_mailboxLocks[key];
    final completer=Completer<void>();
    _mailboxLocks[key]=completer.future;
    try {
      if(previous!=null)await previous;
      return await operation();
    }finally {
      completer.complete();
      if(identical(_mailboxLocks[key],completer.future)){
        _mailboxLocks.remove(key);
      }
    }
  }
  String _pageKey(String owner,String conversation)=>'$owner|$conversation';

  bool hasOlderMessages(String owner,String conversation){
    final key=_pageKey(owner,conversation);
    return _olderCursors.containsKey(key) && _olderCursors[key]!=null;
  }

  Future<bool> secureReady() async {
    if(!cipher.independentlyVerified)return false;
    final capability=await api.capabilities();
    if(!capability.available || !capability.e2eeClientVerified)return false;
    if(cipher is OrbitMessagingVodozemacCipher) {
      await _ensureReviewedDeviceKeys();
    }
    return true;
  }

  /// Atomically register the audited native provider on the first successful
  /// chat access. This cannot silently recreate keys after a rejected
  /// identity rotation; Laravel 409 is surfaced for explicit user review.
  Future<void> _ensureReviewedDeviceKeys({bool force=false}) async {
    final owner=await api.owner;
    await _serialMailbox(owner,'__crypto__',() async {
      final bundle=await cipher.setupDevice();
      final identityKey='$owner|${bundle.identityEd25519}';
      // A previously registered identity may have a newly prepared
      // replenishment batch. Do not skip uploading those new public keys.
      if(!force && _registeredNativeIdentities.contains(identityKey) &&
          bundle.oneTimePrekeys.isEmpty)return;
      await api.registerKeys(bundle);
      await cipher.confirmDeviceRegistration();
      _registeredNativeIdentities.add(identityKey);
    });
  }

  Future<void> requireSecure() async {
    if(!await secureReady())throw OrbitMessagingSecurityException(
      OrbitUnconfiguredMessagingCipher.unavailable,503);
  }

  /// Explicit request re-registers native identity after the trusted device
  /// reports an eligible account/key rotation. Do NOT automatically approve
  /// changes in a safety-number mismatch.
  Future<void> setupDevice() async {
    await requireSecure();
    if(cipher is OrbitMessagingVodozemacCipher){
      await _ensureReviewedDeviceKeys(force:true);
    }else{
      final owner=await api.owner;
      await _serialMailbox(owner,'__crypto__',() async {
        await api.registerKeys(await cipher.setupDevice());
        await cipher.confirmDeviceRegistration();
      });
    }
  }

  /// Identity replacements are never accepted automatically. The user
  /// must compare the full safety fingerprint using an independent channel.
  Future<void> acceptVerifiedPeerIdentity({
    required String peerId,required String deviceId,
    required String verifiedFingerprint,
  }) async {
    await requireSecure();
    if(cipher is! OrbitMessagingVodozemacCipher){
      throw OrbitMessagingSecurityException(
        'Reviewed device identity recovery is not installed.',503);
    }
    final owner=await api.owner;
    await _serialMailbox(owner,'__crypto__',() async{
      await (cipher as OrbitMessagingVodozemacCipher)
          .acceptVerifiedPeerIdentity(
        peerId:peerId,deviceId:deviceId,
        verifiedFingerprint:verifiedFingerprint);
    });
  }

  Future<Map<String,OrbitMessagingKeyDirectory>> _recipients(
      OrbitConversation thread) async {
    final owner=await api.owner;
    final users=<String>{owner};
    if(thread.kind=='direct'){
      final peer=thread.peerId;
      if(peer==null)throw OrbitMessagingSecurityException(
        'Conversation does not have an authorized recipient.',409);
      users.add(peer);
    }else if(thread.kind=='circle'){
      final id=thread.circleId;
      if(id==null)throw OrbitMessagingSecurityException(
        'Circle conversation is unavailable.',404);
      for(var page=1;page<=10;page++){
        final roster=await circles.members(id,page:page);
        for(final person in roster.items){
          if(person.role!='restricted')users.add(person.id);
        }
        if(!roster.hasMore)break;
      }
    }else{
      throw OrbitMessagingSecurityException('Unsupported conversation type.',422);
    }
    final resolved=<String,OrbitMessagingKeyDirectory>{};
    for(final id in users){
      try {
        // Enumerating the recipient device roster is read-only. A reviewed
        // ratchet provider must claim a one-time prekey only when establishing
        // an actual new authenticated session; ordinary sends cannot burn it.
        final result=await api.discoverKeys(
          id,consumeOneTimePrekey:false);
        if(result.devices.isEmpty)throw OrbitMessagingSecurityException(
            'Recipient messaging keys are not registered.',409);
        await cipher.verifyPeerIdentity(result);
        resolved[id]=result;
      }on OrbitIdentityException catch(error){
        if(thread.kind=='circle' && id!=owner && error.statusCode==404){
          // Nonconsenting Circle members are never independently decrypted
          // or sent a key. Server rechecks the exact device roster on POST.
          continue;
        }
        rethrow;
      }
    }
    if(resolved.length<2)throw OrbitMessagingSecurityException(
      'No eligible encrypted recipients are available.',409);
    return resolved;
  }

  Future<OrbitMessagingSendResult> sendText(
      OrbitConversation thread,String message) async {
    final content=message.trim();
    if(content.isEmpty)throw ArgumentError('Enter a message.');
    if(content.runes.length>4096)throw ArgumentError('Message is too long.');
    return sendEncrypted(thread,kind:'text',data:Uint8List.fromList(
      utf8.encode(content)));
  }

  /// Attachment manifest contains only an opaque M6 media reference, never
  /// a readable URL, content key, phone storage path or media plaintext.
  Future<OrbitMessagingSendResult> sendMedia(
      OrbitConversation thread,OrbitEncryptedChatMedia media) =>
    sendEncrypted(thread,kind:media.kind,
      data:Uint8List.fromList(utf8.encode(media.encode())));

  Future<OrbitMessagingSendResult> sendReaction(
      OrbitConversation thread,{required String targetId,
      required String? selected}) async {
    if(targetId.isEmpty)throw const FormatException('Target message required.');
    return sendEncrypted(thread,kind:'reaction',
      data:OrbitEncryptedReaction(targetId:targetId,selected:selected).encode());
  }

  Future<OrbitMessagingSendResult> sendReply(
      OrbitConversation thread,{required String targetId,
      required String text}) async {
    return sendEncrypted(thread,kind:'reply',
      data:OrbitEncryptedReply(targetId:targetId,text:text).encode());
  }

  Future<OrbitMessagingSendResult> sendEncrypted(
      OrbitConversation thread,{required String kind,
      required Uint8List data}) async {
    if(!const ['text','emoji','image','voice','video','reaction','reply']
        .contains(kind)||data.isEmpty||data.length>22000){
      throw OrbitMessagingSecurityException('Unsupported encrypted payload.',422);
    }
    await requireSecure();
    final account=await api.owner;
    // A single owner-wide lock is conservative but ensures two concurrent
    // chats cannot encrypt against the same recipient device ratchet state.
    // Only ciphertext and state durably committed by the reviewed provider
    // may leave this critical section.
    return _serialMailbox(account,'__crypto__',
      ()=>_sendEncryptedLocked(thread,kind,data,account));
  }

  Future<OrbitMessagingSendResult> _sendEncryptedLocked(
      OrbitConversation thread,String kind,Uint8List data,
      String account) async {
    // Server epoch changes on Circle membership/consent/approved-device
    // changes. Requery before every group send; an old epoch is never reused.
    if(thread.kind=='circle'){
      if(thread.circleId==null)throw OrbitMessagingSecurityException(
        'Circle is unavailable.',409);
      final current=await api.circle(thread.circleId!);
      if(current.id!=thread.id ||current.groupEpoch!=thread.groupEpoch){
        throw OrbitMessagingSecurityException(
          'Circle recipients changed. Refresh keys before sending.',409);
      }
    }
    final devices=await _recipients(thread);
    if(thread.kind=='circle'){
      // A server epoch is an access-control fence, not an encryption key.
      // Require the vetted provider to rotate and distribute actual group
      // sender keys before this message can be encrypted.
      await cipher.prepareGroupEpoch(
        conversationId:thread.id,
        groupEpoch:thread.groupEpoch,
        recipients:devices,
      );
    }
    final encrypted=await cipher.encrypt(
      conversationId:thread.id,groupEpoch:thread.groupEpoch,
      kind:kind,plaintext:data,recipients:devices,
    );
    if(!cipher.independentlyVerified || encrypted.protocol!=cipher.protocol ||
       encrypted.envelopes.isEmpty ||
       encrypted.groupEpoch!=thread.groupEpoch){
      throw OrbitMessagingSecurityException(
        'Encrypted delivery validation failed; nothing was shared.',403);
    }
    if(await api.owner!=account)throw OrbitMessagingSecurityException(
      'Account changed. Message was not sent.',401);
    final outgoing=OrbitQueuedCiphertext(
      clientId:const Uuid().v4(),conversationId:thread.id,
      kind:encrypted.kind,protocol:encrypted.protocol,
      groupEpoch:encrypted.groupEpoch,envelopes:encrypted.envelopes,
    );
    // The ratchet provider MUST have committed before encrypt returned.
    // Outbox stores only already-encrypted envelopes, never plaintext.
    // Only app-private encrypted SQLite may keep a pending preview. This
    // preserves the owner's message through a network timeout or app restart
    // without uploading plaintext or falsely showing a delivered receipt.
    final preview=kind=='reaction'?null:OrbitLocalDecryptedMessage(
      id:'local-${outgoing.clientId}',conversationId:thread.id,
      senderId:account,kind:kind,text:utf8.decode(data),
      createdAt:DateTime.now().toUtc());
    await vault.queue(outgoing,preview:preview);
    try{
      final accepted=await api.publish(thread.id,
        clientId:outgoing.clientId,kind:outgoing.kind,
        protocol:outgoing.protocol,groupEpoch:outgoing.groupEpoch,
        envelopes:outgoing.envelopes);
      if(!accepted.accepted)throw OrbitMessagingSecurityException(
          'Encrypted message not acknowledged.',503);
      await vault.acknowledge(outgoing.clientId);
      return OrbitMessagingSendResult(accepted:true,queued:false);
    }on OrbitIdentityException catch(error){
      if(error.statusCode==null || error.statusCode==408 ||
          error.statusCode==429 || error.statusCode==502 ||
          error.statusCode==503 || error.statusCode==504){
        return OrbitMessagingSendResult(
          accepted:false,queued:true,clientId:outgoing.clientId);
      }
      // Never auto-rekey or retry a permanently revoked recipient/epoch.
      // The persisted flag ensures "Failed" survives app restarts and
      // prevents an obsolete ciphertext from leaving after another poll.
      await vault.markNeedsReview(outgoing.clientId);
      throw OrbitQueuedMessageException(outgoing.clientId,
        needsReview:true);
    }
  }

  /// Foreground HTTPS retry of already-encrypted envelopes only.
  /// Policy/epoch mismatches remain pending and are never silently dropped.
  Future<OrbitMessagingRetryResult> retryPending() async {
    await requireSecure();
    final owner=await api.owner;
    return _serialMailbox(owner,'__crypto__',() async {
      var sent=0;
    var needsReview=0;
    for(final pending in await vault.pending()){
      if(await api.owner!=owner)break;
      if(await vault.requiresReview(pending.clientId)){
        needsReview++;
        // Preserve send order and require explicit owner review.
        break;
      }
      try {
        final result=await api.publish(pending.conversationId,
          clientId:pending.clientId,kind:pending.kind,
          protocol:pending.protocol,groupEpoch:pending.groupEpoch,
          envelopes:pending.envelopes);
        if(result.accepted){
          await vault.acknowledge(pending.clientId);
          sent++;
        }
      }on OrbitIdentityException catch(error){
        if(error.statusCode==null || error.statusCode==408 ||
            error.statusCode==429 || error.statusCode==502 ||
            error.statusCode==503 || error.statusCode==504)break;
        await vault.markNeedsReview(pending.clientId);
        needsReview++;
        // Preserve send order when the oldest ciphertext needs re-approval;
        // do not deliver later messages ahead of a revoked-key envelope.
        break;
      }
    }
      return OrbitMessagingRetryResult(sent:sent,needsReview:needsReview);
    });
  }

  /// User-confirmed discard only. Never auto-re-encrypt or re-send a
  /// permanently rejected ciphertext after recipient/key/epoch changes.
  Future<int> discardFailedQueued(OrbitConversation thread) async{
    await requireSecure();
    final owner=await api.owner;
    return _serialMailbox(owner,'__crypto__',() async{
      return vault.discardReviewRequired(thread.id);
    });
  }

  /// Foreground sync of the newest server envelopes. Keep the original
  /// backfill cursor across periodic refreshes instead of returning to page 1.
  Future<List<OrbitLocalDecryptedMessage>> refresh(
      OrbitConversation thread,{int limit=200}) async {
    await requireSecure();
    final owner=await api.owner;
    return _serialMailbox(owner,'__crypto__',() async {
      if(thread.kind=='circle'){
        await cipher.refreshGroupKeys(thread.id,thread.groupEpoch);
      }
      final page=await api.sync(thread.id,limit:limit.clamp(1,200));
      _olderCursors.putIfAbsent(
        _pageKey(owner,thread.id),()=>page.nextCursor);
      await _commitPage(thread,owner,page);
      return vault.history(thread.id,limit:limit);
    });
  }

  /// Decrypt at most one older page through the same verified ratchet provider,
  /// using the server's opaque cursor and current authorization checks.
  /// Returns ONLY messages newly stored during this request. Existing chat
  /// widgets prepend them without changing the approved Orbit UI.
  Future<List<OrbitLocalDecryptedMessage>> loadOlder(
      OrbitConversation thread,{int limit=50}) async {
    await requireSecure();
    final owner=await api.owner;
    final key=_pageKey(owner,thread.id);
    if(!_olderCursors.containsKey(key)) {
      // Initialize a cursor without pretending older messages are absent.
      await refresh(thread);
    }
    return _serialMailbox(owner,'__crypto__',() async {
      final cursor=_olderCursors[key];
      if(cursor==null)return const <OrbitLocalDecryptedMessage>[];
      if(thread.kind=='circle'){
        await cipher.refreshGroupKeys(thread.id,thread.groupEpoch);
      }
      final page=await api.envelopes(
        thread.id,cursor:cursor,limit:limit.clamp(1,50));
      final items=await _commitPage(thread,owner,page);
      if(await api.owner!=owner){
        throw OrbitMessagingSecurityException(
          'Account changed while retrieving older messages.',401);
      }
      _olderCursors[key]=page.nextCursor;
      return items..sort((a,b)=>a.createdAt.compareTo(b.createdAt));
    });
  }

  Future<List<OrbitLocalDecryptedMessage>> _commitPage(
      OrbitConversation thread,String owner,OrbitEnvelopePage page) async {
    // Delete only messages this authenticated device actually received,
    // as proved by the server's device-scoped deletion receipts. Delete the
    // local cached copy before repainting or acknowledging newer envelopes.
    if(page.redactedMessageIds.isNotEmpty){
      final key=_pageKey(owner,thread.id);
      _redactedByConversation.putIfAbsent(key,()=><String>{})
          .addAll(page.redactedMessageIds);
      for(final id in page.redactedMessageIds.toSet()){
        if(await api.owner!=owner)throw OrbitMessagingSecurityException(
          'Account changed before message redaction sync.',401);
        await vault.deleteMessage(thread.id,id);
      }
    }
    final saved=<OrbitLocalDecryptedMessage>[];
    for(final encrypted in page.items.reversed){
      if(await api.owner!=owner)throw OrbitMessagingSecurityException(
        'Account changed while decrypting.',401);
      // A late/replayed envelope must not resurrect a message already
      // removed by an authenticated device-specific deletion receipt.
      if(_redactedByConversation[_pageKey(owner,thread.id)]
          ?.contains(encrypted.messageId)==true)continue;
      if(await vault.hasMessage(thread.id,encrypted.messageId)){
        await cipher.confirmStoredDecryption(encrypted.id);
        continue;
      }
      try{
        final decrypted=await cipher.decrypt(
          envelope:encrypted,conversationId:thread.id);
        final text=utf8.decode(decrypted);
        final message=OrbitLocalDecryptedMessage(
          id:encrypted.messageId,conversationId:thread.id,
          senderId:encrypted.senderId,kind:encrypted.kind,
          text:text,createdAt:encrypted.createdAt,
          envelopeId:encrypted.id);
        // Keep verified plaintext in the encrypted local vault before
        // acknowledging receipt. Neither HTTP polling nor pagination may
        // advance the ratchet a second time for the same committed message.
        await vault.saveDecrypted(message);
        await cipher.confirmStoredDecryption(encrypted.id);
        saved.add(message);
        if(encrypted.senderId!=owner){
          await api.delivered(thread.id,encrypted.id);
        }
      }catch(error){
        if(error is OrbitMessagingSecurityException ||
            error is FormatException) {
          throw OrbitMessagingSecurityException(
            'An encrypted message could not be authenticated. '
            'It remains pending and was not acknowledged.',409);
        }
        rethrow;
      }
    }
    return saved;
  }

  Future<void> redactOwn(OrbitConversation thread,String messageId) async {
    await requireSecure();
    if(messageId.startsWith('local-')){
      throw OrbitMessagingSecurityException(
        'Message has not been acknowledged by the server.',409);
    }
    await api.redact(thread.id,messageId);
    await vault.deleteMessage(thread.id,messageId);
  }

  Future<void> viewed(OrbitConversation thread,String envelopeId,
      Duration visible) async {
    await requireSecure();
    if(visible.inMilliseconds<600)return;
    await api.read(thread.id,envelopeId,visible);
  }

  Future<void> purge(String owner) async {
    if(owner.isEmpty)return;
    await _serialMailbox(owner,'__crypto__',() async {
      await cipher.purgeForOwner(owner);
      await vault.purge(owner);
      _olderCursors.removeWhere((key,_)=>key.startsWith('$owner|'));
      _redactedByConversation.removeWhere((key,_)=>key.startsWith('$owner|'));
      _registeredNativeIdentities.removeWhere((key)=>key.startsWith('$owner|'));
    });
  }
}
class OrbitMessagingSendResult {
  const OrbitMessagingSendResult({
    required this.accepted,required this.queued,this.clientId,
  });
  final bool accepted,queued;
  // Stable queue ID so a waiting bubble can be reconciled after restart.
  final String? clientId;
}
class OrbitMessagingRetryResult {
  const OrbitMessagingRetryResult({required this.sent,required this.needsReview});
  final int sent,needsReview;
}
