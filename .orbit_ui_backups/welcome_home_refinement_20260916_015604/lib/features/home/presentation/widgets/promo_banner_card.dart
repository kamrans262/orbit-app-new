import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/home_models.dart';
import 'home_media_image.dart';

class PromoBannerCard extends StatelessWidget {
  const PromoBannerCard({required this.data, required this.onTap, super.key});

  final PromoBannerData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F0FF),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: HomeMediaImage(
                path: data.backgroundImagePath,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                fallback: const ColoredBox(color: Color(0xFFF4F0FF)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 82),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox.square(
                              dimension: 32,
                              child: HomeMediaImage(
                                path: data.logoImagePath,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 13,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F1724),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4A4A6A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
