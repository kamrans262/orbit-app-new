import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/profile_models.dart';
import 'profile_media_image.dart';

class ProfileMomentTile extends StatelessWidget {
  const ProfileMomentTile({
    required this.moment,
    required this.onTap,
    super.key,
  });

  static const double radius = 15;

  final ProfileMomentData moment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: <Widget>[
              ProfileMediaImage(
                assetPath: moment.imagePath,
                imageUrl: moment.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              if (moment.remainingCount != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x73000000),
                    child: Center(
                      child: Text(
                        '${moment.remainingCount}+',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              if (moment.likeCount != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LikeBadge(count: moment.likeCount!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikeBadge extends StatelessWidget {
  const _LikeBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x73000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.favorite_rounded,
              size: 14,
              color: Color(0xFFFF4757),
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 64),
              child: Text(
                _formatCount(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int value) {
    if (value < 1000) {
      return '$value';
    }
    if (value < 1000000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K';
    }
    final millions = value / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M';
  }
}
