import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/models/home_models.dart';
import 'home_media_image.dart';

/// Home-only landscape moment tile; the main Moments screen is untouched.
class HomeRecentMomentTile extends StatelessWidget {
  const HomeRecentMomentTile({
    required this.width,
    required this.data,
    required this.onTap,
    super.key,
  });

  final double width;
  final MomentData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = data.isSenderOnline ?? false;
    return SizedBox(
      width: width,
      child: Material(
        color: const Color(0xFFEFF1F5),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              HomeMediaImage(path: data.imagePath, bytes:data.encryptedImageBytes, fit: BoxFit.cover),
              if (data.mediaKind == 'video' || data.mediaKind == 'audio')
                Positioned(
                  top: 5,right: 5,
                  child:Icon(data.mediaKind == 'video'
                    ? Icons.videocam_rounded : Icons.mic_rounded,
                    size:18,color:Colors.white),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Color(0xB0000000)],
                    stops: <double>[0.3, 1],
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 3,
                bottom: 5,
                child: Row(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 25,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(1),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: HomeAvatar(
                              imagePath: data.senderAvatarPath ?? '',
                              name: data.name,
                              size: 23,
                            ),
                          ),
                          if (data.isSenderOnline != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: online
                                    ? AppColors.avatarGreen
                                    : AppColors.textMuted,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            data.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 10,
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            data.timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 9,
                              height: 1.1,
                              color: Color(0xFFE2E8F0),
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
      ),
    );
  }
}
