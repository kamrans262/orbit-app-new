import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/moments_models.dart';
import 'moment_media_image.dart';

class MomentProfileAvatar extends StatelessWidget {
  const MomentProfileAvatar({
    required this.author,
    required this.size,
    this.borderColor,
    this.borderWidth = 0,
    super.key,
  });

  final MomentAuthorData author;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(author.name);
    final innerSize = (size - (borderWidth * 2)).clamp(1, size).toDouble();

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: borderColor ?? Colors.transparent,
      ),
      child: ClipOval(
        child: SizedBox.square(
          dimension: innerSize,
          child: MomentMediaImage(
            path: author.imagePath,
            fit: BoxFit.cover,
            fallback: ColoredBox(
              color: const Color(0xFFF0ECF8),
              child: Center(
                child: Text(
                  initials,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: size * 0.28,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }
}
