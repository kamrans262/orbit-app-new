import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_emoji_safe_text.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.heading,
    required this.subtitle,
    this.headingKey,
    this.subtitleKey,
    super.key,
  });

  static const double headingToSubtitleGap = 5;

  final String heading;
  final String subtitle;
  final Key? headingKey;
  final Key? subtitleKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (Theme.of(context).platform == TargetPlatform.iOS &&
            heading.contains('\u{1F44B}'))
          AppEmojiSafeText(
            heading,
            key: headingKey,
            textAlign: TextAlign.center,
            style: _headingStyle,
          )
        else
          Text(
            heading,
            key: headingKey,
            textAlign: TextAlign.center,
            style: _headingStyle,
          ),
        const SizedBox(height: headingToSubtitleGap),
        Text(
          subtitle,
          key: subtitleKey,
          textAlign: TextAlign.center,
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
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  static const _headingStyle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: Color(0xFF0F1724),
  );
}
