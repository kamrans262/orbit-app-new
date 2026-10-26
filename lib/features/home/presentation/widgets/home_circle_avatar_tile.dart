import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/models/home_models.dart';
import 'home_media_image.dart';

/// Home-only horizontal friend presentation; keeps FavoritePersonTile intact.
class HomeCircleAvatarTile extends StatelessWidget {
  const HomeCircleAvatarTile({
    required this.data,
    required this.onTap,
    super.key,
  });

  final FavoritePersonData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online =
        data.isOnline ??
        (data.status.toLowerCase().contains('active now') ||
            data.status.toLowerCase().trim() == 'online');
    final statusLabel = online
        ? 'Online'
        : data.status.replaceFirst(
            RegExp(r'^Active\s+', caseSensitive: false),
            '',
          );

    return SizedBox(
      width: 88,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox.square(
                dimension: 80,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 1,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      child: HomeAvatar(
                        imagePath: data.imagePath,
                        name: data.name,
                        size: 74,
                      ),
                    ),
                    if (data.isOnline != null ||
                        data.status.toLowerCase().contains('active now'))
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          color: online
                              ? AppColors.avatarGreen
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F1724),
                ),
              ),
              Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
