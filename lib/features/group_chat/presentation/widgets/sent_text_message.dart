import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/chat/chat_rich_text.dart';
import '../../domain/models/group_chat_models.dart';
import 'chat_timestamp.dart';

class SentTextMessage extends StatelessWidget {
  const SentTextMessage({required this.message, super.key});

  final GroupChatMessage message;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.74;
    final value = (message.text ?? '').trim();
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                child: ChatRichText(
                  value.isEmpty ? 'Message unavailable' : value,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            ChatTimestamp(message.timestamp, alignment: TextAlign.right),
          ],
        ),
      ),
    );
  }
}
