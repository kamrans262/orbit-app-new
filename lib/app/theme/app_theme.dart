import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_page_transitions.dart';

abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: const <String>[
        'Noto Color Emoji',
        'Apple Color Emoji',
        'Segoe UI Emoji',
      ],
      pageTransitionsTheme: AppPageTransitions.theme,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryStart,
        brightness: Brightness.light,
        surface: AppColors.background,
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTypography.largeHeading,
        headlineMedium: AppTypography.smallHeading,
        bodyMedium: AppTypography.body,
      ),
    );
  }
}
