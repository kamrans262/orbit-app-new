import 'dart:typed_data';
enum GroupChatViewState { loading, loaded, error }

enum GroupChatMessageType {
  receivedText,
  sentText,
  sentVoice,
  receivedVoice,
  receivedImage,
  sentImage,
  receivedMultiImage,
  sentMultiImage,
  futureAudio,
  futureVideo,
  futureFile,
  futureSystemMessage,
}

enum ChatReactionState { none, liked, disliked }

class GroupParticipant {
  const GroupParticipant({
    required this.id,
    required this.name,
    this.avatarPath,
  });

  final String id;
  final String name;
  final String? avatarPath;
}

class GroupChatMessage {
  const GroupChatMessage({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.isMine,
    required this.timestamp,
    required this.createdAt,
    this.senderAvatar,
    this.text,
    this.audioUrl,
    this.audioBytes,
    this.audioDuration,
    this.images = const <String>[],
    this.imageBytes,
    this.videoBytes,
    this.videoMediaId,
    this.reactionAvatars = const <String>[],
    this.reactionState = ChatReactionState.none,
    this.reactions=const <String,int>{},
    this.selectedReaction,
    this.readEnvelopeId,
    this.readRecipientNames=const <String>[],
    this.deliveredDevices=0,
    this.isQueued=false,
  });

  final String id;
  final GroupChatMessageType type;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final bool isMine;
  final String? text;
  final String? audioUrl;
  final Uint8List? audioBytes;
  final Duration? audioDuration;
  final List<String> images;
  final Uint8List? imageBytes;
  final Uint8List? videoBytes;
  final String? videoMediaId;
  final List<String> reactionAvatars;
  final String timestamp;
  final ChatReactionState reactionState;
  final Map<String,int> reactions;
  final String? selectedReaction;
  final String? readEnvelopeId;
  // Server-filtered per-recipient acknowledgements only. Names are resolved
  // locally from the currently authorized Circle roster.
  final List<String> readRecipientNames;
  final int deliveredDevices;
  final bool isQueued;
  final DateTime createdAt;

  GroupChatMessage copyWith({
    String? id,ChatReactionState? reactionState,String? text,bool? isQueued}) {
    return GroupChatMessage(
      id: id ?? this.id,
      type: type,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      isMine: isMine,
      text: text ?? this.text,
      audioUrl: audioUrl,
      audioBytes:audioBytes,
      audioDuration:audioDuration,
      images: images,
      imageBytes:imageBytes,
      videoBytes:videoBytes,
      videoMediaId:videoMediaId,
      reactionAvatars: reactionAvatars,
      timestamp: timestamp,
      reactionState: reactionState ?? this.reactionState,
      reactions:reactions,selectedReaction:selectedReaction,
      readEnvelopeId:readEnvelopeId,
      readRecipientNames:readRecipientNames,
      deliveredDevices:deliveredDevices,
      isQueued:isQueued??this.isQueued,
      createdAt: createdAt,
    );
  }
}
