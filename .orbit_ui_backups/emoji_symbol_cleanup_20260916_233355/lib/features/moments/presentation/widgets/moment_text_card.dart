import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/moments_models.dart';
import 'moment_profile_avatar.dart';
import '../../../../core/widgets/app_emoji_safe_text.dart';

class MomentTextCard extends StatelessWidget {
  const MomentTextCard({
    required this.data,
    required this.onMenuPressed,
    super.key,
  });

  final MomentTextFeedItem data;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MomentProfileAvatar(author: data.author, size: 38),
                const SizedBox(width: 9),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          data.author.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontFamilyFallback: const <String>[
                              'Noto Color Emoji',
                              'Apple Color Emoji',
                              'Segoe UI Emoji',
                            ],
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F1724),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.timeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontFamilyFallback: const <String>[
                              'Noto Color Emoji',
                              'Apple Color Emoji',
                              'Segoe UI Emoji',
                            ],
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF8A85A8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Moment options',
                  onPressed: onMenuPressed,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF8A85A8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppEmojiSafeAppEmojiSafeText(
              data.text,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8A85A8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
