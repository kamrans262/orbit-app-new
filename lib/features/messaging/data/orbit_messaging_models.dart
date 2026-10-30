import '../../auth/data/orbit_identity_client.dart';

/// Metadata only. Ciphertext never becomes a plain message in this layer.
class OrbitConversation {
  const OrbitConversation({required this.id,required this.kind,
    required this.groupEpoch,required this.createdAt,this.peerId,
    this.circleId,this.unreadEnvelopes=0,this.archived=false});
  final String id,kind;
  final String? peerId,circleId;
  final DateTime createdAt;
  final int groupEpoch,unreadEnvelopes;
  final bool archived;
  factory OrbitConversation.fromJson(Map<String,dynamic> j)=>OrbitConversation(
    id:j['id'] as String,kind:j['kind'] as String,
    peerId:j['peer_id'] as String?,circleId:j['circle_id'] as String?,
    groupEpoch:(j['group_epoch'] as num).toInt(),
    createdAt:DateTime.parse(j['created_at'] as String),
    unreadEnvelopes:(j['unread_envelopes'] as num?)?.toInt()??0,
    archived:j['archived']==true);
}
class OrbitConversationPage {
  const OrbitConversationPage(this.items,this.page,this.hasMore);
  final List<OrbitConversation> items;
  final int page;
  final bool hasMore;
  factory OrbitConversationPage.fromJson(Map<String,dynamic> j){
    final rows=j['items'];
    if(rows is! List)throw const FormatException('Invalid conversation page.');
    return OrbitConversationPage(rows.map((r)=>OrbitConversation.fromJson(
      Map<String,dynamic>.from(r as Map))).toList(growable:false),
      (j['page'] as num?)?.toInt()??1,j['has_more']==true);
  }
}
class OrbitMessagingCapabilities {
  const OrbitMessagingCapabilities({required this.available,
    required this.e2eeClientVerified,required this.circleEnabled,
    required this.realtimeAvailable,required this.pushAvailable});
  final bool available,e2eeClientVerified,circleEnabled,realtimeAvailable,pushAvailable;
  factory OrbitMessagingCapabilities.fromJson(Map<String,dynamic> j)=>
    OrbitMessagingCapabilities(available:j['available']==true,
      e2eeClientVerified:j['e2ee_client_verified']==true,
      circleEnabled:j['circle_enabled']==true,
      realtimeAvailable:j['realtime_available']==true,
      pushAvailable:j['push_available']==true);
}
class OrbitCipherEnvelope {
  const OrbitCipherEnvelope({required this.deviceId,
    required this.ciphertextB64,required this.headerB64});
  final String deviceId,ciphertextB64,headerB64;
  Map<String,Object?> toJson()=>{'device_id':deviceId,
    'ciphertext_b64':ciphertextB64,'protocol_header_b64':headerB64};
}
class OrbitMailboxEnvelope {
  const OrbitMailboxEnvelope({required this.id,required this.messageId,
    required this.senderId,required this.senderDeviceId,required this.kind,
    required this.protocol,required this.groupEpoch,required this.keyVersion,
    required this.ciphertextB64,required this.headerB64,
    required this.createdAt});
  final String id,messageId,senderId,senderDeviceId,kind,protocol;
  final int groupEpoch,keyVersion;
  final String ciphertextB64,headerB64;
  final DateTime createdAt;
  factory OrbitMailboxEnvelope.fromJson(Map<String,dynamic> j)=>
    OrbitMailboxEnvelope(id:j['id'] as String,
      messageId:j['message_id'] as String,
      senderId:j['sender_id'] as String,
      senderDeviceId:j['sender_device_id'] as String,
      kind:j['kind'] as String,protocol:j['protocol'] as String,
      groupEpoch:(j['group_epoch'] as num).toInt(),
      keyVersion:(j['recipient_key_version'] as num).toInt(),
      ciphertextB64:j['ciphertext_b64'] as String,
      headerB64:j['protocol_header_b64'] as String,
      createdAt:DateTime.parse(j['created_at'] as String));
}
class OrbitEnvelopePage {
  const OrbitEnvelopePage(this.items,this.nextCursor,{
    this.redactedMessageIds=const <String>[],
  });
  final List<OrbitMailboxEnvelope> items;
  final String? nextCursor;
  // Opaque per-device deletion receipts; no message text or attachment key.
  final List<String> redactedMessageIds;
  factory OrbitEnvelopePage.fromJson(Map<String,dynamic> j) {
    final rows=j['items'];
    final deleted=j['redacted_message_ids'];
    if(rows is! List || (deleted!=null && deleted is! List)){
      throw const FormatException('Invalid encrypted mailbox.');
    }
    return OrbitEnvelopePage(rows.map((v)=>OrbitMailboxEnvelope.fromJson(
      Map<String,dynamic>.from(v as Map))).toList(growable:false),
      j['next_cursor'] as String?,
      redactedMessageIds:deleted==null
        ?const <String>[]
        :List<String>.from(deleted as List,growable:false));
  }
}
class OrbitMessageAccepted {
  const OrbitMessageAccepted(this.id,this.conversationId,this.accepted,this.delivered);
  final String id,conversationId;
  final bool accepted,delivered;
  factory OrbitMessageAccepted.fromJson(Map<String,dynamic> j)=>
    OrbitMessageAccepted(j['id'] as String,j['conversation_id'] as String,
      j['accepted']==true,j['delivered']==true);
}
/// A group sender-key packet is already authenticated and encrypted by the
/// independently reviewed client protocol. This model never stores keys.
class OrbitSenderKeyEnvelope {
  const OrbitSenderKeyEnvelope({
    required this.id,required this.senderId,required this.senderDeviceId,
    required this.recipientKeyVersion,required this.groupEpoch,
    required this.protocol,required this.ciphertextB64,required this.headerB64,
  });
  final String id,senderId,senderDeviceId,protocol,ciphertextB64,headerB64;
  final int recipientKeyVersion,groupEpoch;
  factory OrbitSenderKeyEnvelope.fromJson(Map<String,dynamic> j)=>
    OrbitSenderKeyEnvelope(
      id:j['id'] as String,
      senderId:j['sender_id'] as String,
      senderDeviceId:j['sender_device_id'] as String,
      recipientKeyVersion:(j['recipient_key_version'] as num).toInt(),
      groupEpoch:(j['group_epoch'] as num).toInt(),
      protocol:j['protocol'] as String,
      ciphertextB64:j['ciphertext_b64'] as String,
      headerB64:j['protocol_header_b64'] as String,
    );
}

class OrbitSenderKeyPage {
  const OrbitSenderKeyPage(this.items,this.nextCursor,this.groupEpoch);
  final List<OrbitSenderKeyEnvelope> items;
  final String? nextCursor;
  final int groupEpoch;
  factory OrbitSenderKeyPage.fromJson(Map<String,dynamic> j){
    final raw=j['items'];
    if(raw is! List)throw const FormatException('Invalid sender-key mailbox.');
    return OrbitSenderKeyPage(
      raw.map((e)=>OrbitSenderKeyEnvelope.fromJson(
        Map<String,dynamic>.from(e as Map))).toList(growable:false),
      j['next_cursor'] as String?,
      (j['group_epoch'] as num).toInt(),
    );
  }
}

class OrbitSenderKeySaved {
  const OrbitSenderKeySaved(this.id,this.groupEpoch,this.stored);
  final String id;
  final int groupEpoch;
  final bool stored;
  factory OrbitSenderKeySaved.fromJson(Map<String,dynamic> j)=>
    OrbitSenderKeySaved(j['id'] as String,
      (j['group_epoch'] as num).toInt(),j['stored']==true);
}

class OrbitMessagingPublicKeyBundle {
  const OrbitMessagingPublicKeyBundle({required this.identityEd25519,
    required this.signedPrekeyX25519,required this.signature,
    required this.signedPrekeyId,required this.oneTimePrekeys,
    this.confirmRotation=false});
  final String identityEd25519,signedPrekeyX25519,signature;
  final int signedPrekeyId;
  final List<OrbitPublicOneTimePrekey> oneTimePrekeys;
  final bool confirmRotation;
  Map<String,Object?> toJson()=>{'identity_ed25519':identityEd25519,
    'signed_prekey_x25519':signedPrekeyX25519,
    'signed_prekey_signature':signature,'signed_prekey_id':signedPrekeyId,
    'one_time_prekeys':oneTimePrekeys.map((v)=>v.toJson()).toList(),
    if(confirmRotation)'confirm_key_rotation':true};
}
class OrbitPublicOneTimePrekey {
  const OrbitPublicOneTimePrekey(this.id,this.publicX25519);
  final int id;
  final String publicX25519;
  Map<String,Object?> toJson()=>{'key_id':id,'public_x25519':publicX25519};
}
class OrbitMessagingRemoteDevice {
  const OrbitMessagingRemoteDevice({required this.id,required this.identity,
    required this.signedPrekey,required this.signature,required this.signedPrekeyId,
    required this.keyVersion,required this.fingerprint,
    this.oneTimeKeyId,this.oneTimePublic});
  final String id,identity,signedPrekey,signature,fingerprint;
  final int signedPrekeyId,keyVersion;
  final int? oneTimeKeyId;
  final String? oneTimePublic;
  factory OrbitMessagingRemoteDevice.fromJson(Map<String,dynamic> j) {
    final raw=j['one_time_prekey'];
    final pre=raw is Map?Map<String,dynamic>.from(raw):null;
    return OrbitMessagingRemoteDevice(id:j['device_id'] as String,
      identity:j['identity_ed25519'] as String,
      signedPrekey:j['signed_prekey_x25519'] as String,
      signature:j['signed_prekey_signature'] as String,
      signedPrekeyId:(j['signed_prekey_id'] as num).toInt(),
      keyVersion:(j['key_version'] as num).toInt(),
      fingerprint:j['fingerprint'] as String,
      oneTimeKeyId:(pre?['key_id'] as num?)?.toInt(),
      oneTimePublic:pre?['public_x25519'] as String?);
  }
}
class OrbitMessagingKeyDirectory {
  const OrbitMessagingKeyDirectory(this.userId,this.devices);
  final String userId;
  final List<OrbitMessagingRemoteDevice> devices;
  factory OrbitMessagingKeyDirectory.fromJson(Map<String,dynamic> j)=>
    OrbitMessagingKeyDirectory(j['user_id'] as String,
      (j['devices'] as List).map((v)=>OrbitMessagingRemoteDevice.fromJson(
        Map<String,dynamic>.from(v as Map))).toList(growable:false));
}

/// A protocol error is not an instruction to reset identity/ratchet state.
class OrbitQueuedMessageException implements Exception {
  const OrbitQueuedMessageException(this.clientId);
  final String clientId;
  @override
  String toString()=>'Encrypted message is queued, not yet delivered.';
}

class OrbitMessagingSecurityException extends OrbitIdentityException {
  OrbitMessagingSecurityException(super.message,[super.statusCode]);
}
