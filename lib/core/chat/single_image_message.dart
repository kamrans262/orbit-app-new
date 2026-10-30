import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import 'chat_media_image.dart';

class SingleImageMessage extends StatelessWidget {
  const SingleImageMessage({
    required this.source,
    this.bytes,
    required this.timestamp,
    required this.isMine,
    this.onTap,
    super.key,
  });

  final String source;
  final Uint8List? bytes;
  final String timestamp;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.58, 250.0);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: width,
                child: ChatMediaImage(source: source,bytes:bytes,fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            timestamp,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              color: Color(0xFF8B95A1),
            ),
          ),
        ],
      ),
    );
  }
}
