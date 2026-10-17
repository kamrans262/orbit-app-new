import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import 'chat_media_image.dart';

class MultipleImageMessage extends StatelessWidget {
  const MultipleImageMessage({
    required this.sources,
    required this.timestamp,
    required this.isMine,
    super.key,
  });

  final List<String> sources;
  final String timestamp;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    if (sources.length == 1) {
      return _SingleFallback(
        source: sources.first,
        timestamp: timestamp,
        isMine: isMine,
      );
    }
    final maxWidth = math.min(MediaQuery.sizeOf(context).width * 0.72, 310.0);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (sources.length == 2) {
                    return SizedBox(
                      height: constraints.maxWidth * 0.55,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: ChatMediaImage(
                              source: sources[0],
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ChatMediaImage(
                              source: sources[1],
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final visible = sources.take(4).toList(growable: false);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visible.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemBuilder: (context, index) => ChatMediaImage(
                      source: visible[index],
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  );
                },
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
      ),
    );
  }
}

class _SingleFallback extends StatelessWidget {
  const _SingleFallback({
    required this.source,
    required this.timestamp,
    required this.isMine,
  });

  final String source;
  final String timestamp;
  final bool isMine;

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
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: width,
              child: ChatMediaImage(source: source),
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
