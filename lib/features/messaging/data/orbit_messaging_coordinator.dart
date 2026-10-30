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

  Future<bool> secureReady() async {
    if(!cipher.independentlyVerified)return false;
    final capability=await api.capabilities();
    return capability.available && capability.e2eeClientVerified;
  }

  Future<void> requireSecure() async {
    if(!await secureReady())throw OrbitMessagingSecurityException(
      OrbitUnconfiguredMessagingCipher.unavailable,503);
  }

  /// The engine owns ALL cryptographic keys and their durable ratchet stores.
  /// Public keys are not registered unless it passed independent verification.
  Future<void> setupDevice() async {
    await requireSecure();
    await api.registerKeys(await cipher.setupDevice());
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
        final result=await api.discoverKeys(id);
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

  Future<OrbitMessagingSendResult> sendEncrypted(
      OrbitConversation thread,{required String kind,
      required Uint8List data}) async {
    if(!const ['text','emoji','image','voice','video','reaction','reply']
        .contains(kind)||data.isEmpty||data.length>22000){
      throw OrbitMessagingSecurityException('Unsupported encrypted payload.',422);
    }
    await requireSecure();
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
    final account=await api.owner;
    final devices=await _recipients(thread);
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
    await vault.queue(outgoing);
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
          error.statusCode==502 || error.statusCode==503 ||
          error.statusCode==504){
        return const OrbitMessagingSendResult(accepted:false,queued:true);
      }
      // Keep the ciphertext intent for explicit review. A 403/409 can mean
      // revoked consent or a changed device/group epoch: never auto-rekey.
      rethrow;
    }
  }

  /// Foreground HTTPS retry of already-encrypted envelopes only.
  /// Policy/epoch mismatches remain pending and are never silently dropped.
  Future<OrbitMessagingRetryResult> retryPending() async {
    await requireSecure();
    final owner=await api.owner;
    var sent=0;
    var needsReview=0;
    for(final pending in await vault.pending()){
      if(await api.owner!=owner)break;
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
            error.statusCode==502 || error.statusCode==503 ||
            error.statusCode==504)break;
        needsReview++;
      }
    }
    return OrbitMessagingRetryResult(sent:sent,needsReview:needsReview);
  }

  Future<List<OrbitLocalDecryptedMessage>> refresh(
      OrbitConversation thread,{int limit=100}) async {
    await requireSecure();
    final owner=await api.owner;
    final page=await api.sync(thread.id,limit:limit);
    for(final encrypted in page.items.reversed){
      if(await api.owner!=owner)throw OrbitMessagingSecurityException(
        'Account changed while decrypting.',401);
      // A ratchet ciphertext can be consumed once. This account-bound lookup
      // avoids double-advancing sender/receiver chains on HTTPS refresh.
      if(await vault.hasMessage(thread.id,encrypted.messageId))continue;
      try{
        final decrypted=await cipher.decrypt(
          envelope:encrypted,conversationId:thread.id);
        final text=utf8.decode(decrypted);
        await vault.saveDecrypted(OrbitLocalDecryptedMessage(
          id:encrypted.messageId,conversationId:thread.id,
          senderId:encrypted.senderId,kind:encrypted.kind,
          text:text,createdAt:encrypted.createdAt));
        // "Delivered" is a local durable-decrypt receipt, not an
        // optimistic network request or a read acknowledgement.
        if(encrypted.senderId!=owner){
          await api.delivered(thread.id,encrypted.id);
        }
      }catch(error){
        if(error is OrbitMessagingSecurityException ||
            error is FormatException) {
          // Unauthenticated or malformed bytes must not change ratchet state
          // or trigger session reset/read receipts.
          continue;
        }
        rethrow;
      }
    }
    return vault.history(thread.id,limit:limit);
  }

  Future<void> viewed(OrbitConversation thread,String envelopeId,
      Duration visible) async {
    await requireSecure();
    if(visible.inMilliseconds<600)return;
    await api.read(thread.id,envelopeId,visible);
  }

  Future<void> purge(String owner) async {
    await cipher.purgeForOwner(owner);
    await vault.purge(owner);
  }
}
class OrbitMessagingSendResult {
  const OrbitMessagingSendResult({required this.accepted,required this.queued});
  final bool accepted,queued;
}
class OrbitMessagingRetryResult {
  const OrbitMessagingRetryResult({required this.sent,required this.needsReview});
  final int sent,needsReview;
}
