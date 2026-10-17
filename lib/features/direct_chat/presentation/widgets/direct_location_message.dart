import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/chat/chat_media_image.dart';
import '../../domain/models/direct_chat_models.dart';

class DirectLocationMessage extends StatelessWidget {
  const DirectLocationMessage({
    required this.message,
    required this.onOpen,
    super.key,
  });

  final DirectChatMessage message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.55, 235.0);
    final mapPath = message.mapImagePath ?? 'assets/orbit_map.png';
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onTap: onOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      height: width * 0.72,
                      width: width,
                      child: ChatMediaImage(
                        source: mapPath,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Container(
                      width: width,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              message.locationName ?? 'Shared location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F1724),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message.timestamp,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 10,
              color: Color(0xFF8B95A1),
            ),
          ),
        ],
      ),
    );
  }
}
