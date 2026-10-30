import 'dart:typed_data';
enum DirectChatViewState { loading, loaded, error }

enum DirectChatMessageType {
  receivedText,
  sentText,
  receivedAudio,
  sentAudio,
  receivedImage,
  sentImage,
  receivedMultiImage,
  sentMultiImage,
  locationMessage,
  futureVideo,
  futureFile,
}

enum DirectChatDeliveryStatus { sending, sent, delivered, read, failed }

class DirectChatPerson {
  const DirectChatPerson({
    required this.id,
    required this.name,
    this.avatarPath,
    this.statusText = 'Live · Miami Beach',
    this.isOnline = true,
  });

  final String id;
  final String name;
  final String? avatarPath;
  final String statusText;
  final bool isOnline;
}

class DirectChatMessage {
  const DirectChatMessage({
    required this.id,
    required this.conversationId,
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
    this.imageUrl,
    this.imageBytes,
    this.videoUrl,
    this.videoBytes,
    this.videoDuration,
    this.images = const <String>[],
    this.latitude,
    this.longitude,
    this.locationName,
    this.mapImagePath,
    this.reactions = const <String, int>{},
    this.selectedReaction,
    this.replyToId,
    this.deliveryStatus = DirectChatDeliveryStatus.sent,
  });

  final String id;
  final String conversationId;
  final DirectChatMessageType type;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final bool isMine;
  final String? text;
  final String? audioUrl;
  final Uint8List? audioBytes;
  final Duration? audioDuration;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? videoUrl;
  final Uint8List? videoBytes;
  final Duration? videoDuration;
  final List<String> images;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? mapImagePath;
  final Map<String, int> reactions;
  final String? selectedReaction;
  final String? replyToId;
  final String timestamp;
  final DirectChatDeliveryStatus deliveryStatus;
  final DateTime createdAt;

  DirectChatMessage copyWith({
    String? text,
    Map<String, int>? reactions,
    String? selectedReaction,
    bool clearSelectedReaction = false,
    DirectChatDeliveryStatus? deliveryStatus,
  }) {
    return DirectChatMessage(
      id: id,
      conversationId: conversationId,
      type: type,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      isMine: isMine,
      text: text ?? this.text,
      audioUrl: audioUrl,
      audioBytes:audioBytes,
      audioDuration: audioDuration,
      imageUrl: imageUrl,
      imageBytes:imageBytes,
      videoUrl:videoUrl,
      videoBytes:videoBytes,
      videoDuration:videoDuration,
      images: images,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      mapImagePath: mapImagePath,
      reactions: reactions ?? this.reactions,
      replyToId:replyToId,
      selectedReaction: clearSelectedReaction
          ? null
          : (selectedReaction ?? this.selectedReaction),
      timestamp: timestamp,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      createdAt: createdAt,
    );
  }
}
