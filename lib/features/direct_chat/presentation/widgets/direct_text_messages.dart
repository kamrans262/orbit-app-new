import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/chat/chat_rich_text.dart';
import '../../domain/models/direct_chat_models.dart';

class DirectReceivedTextMessage extends StatelessWidget {
  const DirectReceivedTextMessage({required this.message, super.key});

  final DirectChatMessage message;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.70,
      310.0,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        SizedBox.square(dimension: 32, child: ClipOval(child: _avatar())),
        const SizedBox(width: 16),
        Flexible(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      child: ChatRichText(
                        message.text ?? '',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.timestamp,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10,
                    color: Color(0xFF8B95A1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar() {
    final path = message.senderAvatar?.trim();
    if (path != null && path.isNotEmpty) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final name = message.senderName.trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return ColoredBox(
      color: const Color(0xFFE7DDF8),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }
}

class DirectSentTextMessage extends StatelessWidget {
  const DirectSentTextMessage({required this.message, super.key});

  final DirectChatMessage message;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.68,
      240.0,
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              Text(message.timestamp,style:const TextStyle(
                fontFamily:AppTypography.fontFamily,fontSize:10,
                color:Color(0xFF8B95A1))),
              if(message.showDeliveryStatus)...[
                const SizedBox(width:3),
                Icon(switch(message.deliveryStatus){
                  DirectChatDeliveryStatus.sending=>Icons.schedule_rounded,
                  DirectChatDeliveryStatus.waiting=>Icons.cloud_off_outlined,
                  DirectChatDeliveryStatus.sent=>Icons.done_rounded,
                  DirectChatDeliveryStatus.delivered=>Icons.done_all_rounded,
                  DirectChatDeliveryStatus.read=>Icons.done_all_rounded,
                  DirectChatDeliveryStatus.failed=>Icons.error_outline_rounded,
                },size:12,color:message.deliveryStatus==DirectChatDeliveryStatus.read
                  ?const Color(0xFF7C5CFC):const Color(0xFF8B95A1)),
                if(message.deliveryStatus==DirectChatDeliveryStatus.sending ||
                   message.deliveryStatus==DirectChatDeliveryStatus.waiting ||
                   message.deliveryStatus==DirectChatDeliveryStatus.failed)...[
                  const SizedBox(width:3),
                  Text(switch(message.deliveryStatus){
                    DirectChatDeliveryStatus.sending=>'Sending',
                    DirectChatDeliveryStatus.waiting=>'Waiting',
                    DirectChatDeliveryStatus.failed=>'Failed',
                    _=>'',
                  },style:const TextStyle(
                    fontFamily:AppTypography.fontFamily,fontSize:10,
                    color:Color(0xFF8B95A1))),
                ],
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  child: ChatRichText(
                    message.text ?? '',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
