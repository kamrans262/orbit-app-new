enum GroupChatViewState { loading, loaded, error }

enum GroupChatMessageType {
  receivedText,
  sentText,
  sentVoice,
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
    this.audioDuration,
    this.images = const <String>[],
    this.reactionAvatars = const <String>[],
    this.reactionState = ChatReactionState.none,
  });

  final String id;
  final GroupChatMessageType type;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final bool isMine;
  final String? text;
  final String? audioUrl;
  final Duration? audioDuration;
  final List<String> images;
  final List<String> reactionAvatars;
  final String timestamp;
  final ChatReactionState reactionState;
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
      audioDuration: audioDuration,
      images: images,
      reactionAvatars: reactionAvatars,
      timestamp: timestamp,
      reactionState: reactionState ?? this.reactionState,
      createdAt: createdAt,
    );
  }
}
