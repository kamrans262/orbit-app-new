import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/moments_models.dart';
import 'moment_media_image.dart';
import 'moment_profile_avatar.dart';

class MomentVideoPlaceholderCard extends StatelessWidget {
  const MomentVideoPlaceholderCard({
    required this.data,
    required this.onTap,
    super.key,
  });

  final MomentFutureVideoFeedItem data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  MomentMediaImage(path: data.thumbnailPath, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x26000000)),
                  ),
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xCCFFFFFF),
                      ),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 30,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MomentProfileAvatar(author: data.author, size: 36),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          data.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F1724),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.caption,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            height: 1.35,
                            color: Color(0xFF8A85A8),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.timeLabel,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
