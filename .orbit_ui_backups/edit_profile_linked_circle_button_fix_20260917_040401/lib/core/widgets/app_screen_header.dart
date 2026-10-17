import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import 'app_circular_icon_button.dart';

/// Shared Orbit detail-screen header.
///
/// It deliberately reuses [AppCircularIconButton] so the back control keeps
/// the same size, shadow, shape, and interaction treatment as existing Orbit
/// screens while centralizing title spacing for future detail screens.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    required this.title,
    this.onBack,
    this.backButtonKey,
    this.titleKey,
    super.key,
  });

  static const double height = 30;
  static const double backToTitleGap = 10;

  final String title;
  final VoidCallback? onBack;
  final Key? backButtonKey;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: AppCircularIconButton(
              key: backButtonKey,
              semanticLabel: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icons.chevron_left_rounded,
              iconSize: 24,
              iconColor: Colors.black,
            ),
          ),
          const SizedBox(width: backToTitleGap),
          Expanded(
            child: Text(
              title,
              key: titleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F1724),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
