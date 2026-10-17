import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/chat/chat_media_image.dart';

class LiveLocationCard extends StatelessWidget {
  const LiveLocationCard({
    required this.mapImagePath,
    required this.title,
    required this.subtitle,
    required this.onViewMap,
    super.key,
  });

  final String mapImagePath;
  final String title;
  final String subtitle;
  final VoidCallback onViewMap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              height: 118,
              child: ChatMediaImage(
                source: mapImagePath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: <Widget>[
                  const SizedBox.square(
                    dimension: 30,
                    child: Center(
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: _gradientShader,
                        child: Icon(
                          Icons.near_me_outlined,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F1724),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8B95A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: onViewMap,
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          child: Text(
                            'View map',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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

  static Shader _gradientShader(Rect bounds) => const LinearGradient(
    colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
  ).createShader(bounds);
}
