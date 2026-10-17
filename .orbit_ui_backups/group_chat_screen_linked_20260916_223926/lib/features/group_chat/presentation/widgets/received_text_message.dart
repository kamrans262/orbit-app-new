import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/group_chat_models.dart';
import 'chat_avatar.dart';
import 'chat_timestamp.dart';
import 'gradient_text.dart';

class ReceivedTextMessage extends StatelessWidget {
  const ReceivedTextMessage({required this.message, super.key});

  final GroupChatMessage message;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.70;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ChatAvatar(name: message.senderName, imagePath: message.senderAvatar),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    child: GradientText(
                      (message.text ?? '').trim().isEmpty
                          ? 'Message unavailable'
                          : message.text!.trim(),
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                ChatTimestamp(message.timestamp),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
