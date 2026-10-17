import 'package:flutter/material.dart';

import '../../../../core/chat/chat_audio_message.dart';
import '../../domain/models/group_chat_models.dart';

class SentVoiceMessage extends StatelessWidget {
  const SentVoiceMessage({required this.message, super.key});

  final GroupChatMessage message;

  @override
  Widget build(BuildContext context) {
    return ChatAudioMessage(
      audioSource: message.audioUrl ?? 'assets/audio/group_voice_demo.wav',
      duration: message.audioDuration ?? const Duration(seconds: 8),
      timestamp: message.timestamp,
      isMine: true,
    );
  }
}
