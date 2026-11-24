import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const String fontFamily = 'Poppins';

  static const List<String> emojiFontFallback = <String>[
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Samsung Color Emoji',
    'Segoe UI Emoji',
  ];

  /// Standalone emoji must use the native Apple glyph font on iOS/macOS
  /// rather than the app's Latin text font or Android-only Noto.
  static String? emojiFontFamily(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? 'Apple Color Emoji'
        : null;
  }

  static const TextStyle largeHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 29,
    height: 1.34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );

  static const TextStyle smallHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
}
