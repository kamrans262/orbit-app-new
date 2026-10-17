import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/moments_models.dart';
import 'moment_media_image.dart';

class MomentStoryAvatar extends StatelessWidget {
  const MomentStoryAvatar({required this.data, required this.onTap, super.key});

  static const double avatarSize = 54;

  final MomentStoryData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: avatarSize,
              height: avatarSize,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF7C3AED), width: 2),
              ),
              child: data.isAddStory
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 24,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    )
                  : ClipOval(
                      child: SizedBox.square(
                        dimension: 50,
                        child: MomentMediaImage(
                          path: data.imagePath,
                          fit: BoxFit.cover,
                          fallback: const ColoredBox(
                            color: Color(0xFFF0ECF8),
                            child: Center(
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 24,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              data.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
