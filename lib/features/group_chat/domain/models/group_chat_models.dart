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
    this.reactionAvatars = const <String>[],
    this.reactionState = ChatReactionState.none,
    this.reactions=const <String,int>{},
    this.selectedReaction,
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
  final List<String> reactionAvatars;
  final String timestamp;
  final ChatReactionState reactionState;
  final Map<String,int> reactions;
  final String? selectedReaction;
  final DateTime createdAt;

  GroupChatMessage copyWith({ChatReactionState? reactionState, String? text}) {
    return GroupChatMessage(
      id: id,
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
      reactionAvatars: reactionAvatars,
      timestamp: timestamp,
      reactionState: reactionState ?? this.reactionState,
      reactions:reactions,selectedReaction:selectedReaction,
      createdAt: createdAt,
    );
  }
}
