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
    this.prominent = false,
    super.key,
  });

  static const double height = 30;
  static const double prominentHeight = 44;
  static const double backToTitleGap = 10;

  final String title;
  final VoidCallback? onBack;
  final Key? backButtonKey;
  final Key? titleKey;
  /// Matches the 44px, 24pt Friends / Find Friends header when enabled.
  /// Existing detail headers retain their original 30px, 16pt treatment.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: prominent ? prominentHeight : height,
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
              size: prominent ? 40 : 30,
            ),
          ),
          const SizedBox(width: backToTitleGap),
          Expanded(
            child: Text(
              title,
              key: titleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: prominent ? 24 : 16,
                height: prominent ? 1.15 : 1.2,
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
