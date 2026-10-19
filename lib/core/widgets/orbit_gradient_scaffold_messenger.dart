import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Uses the existing Orbit CTA gradient for every app SnackBar, including
/// messages from screens that still construct a regular Material SnackBar.
class OrbitGradientScaffoldMessenger extends ScaffoldMessenger {
  const OrbitGradientScaffoldMessenger({required super.child, super.key});

  @override
  ScaffoldMessengerState createState() => _OrbitGradientScaffoldMessengerState();
}

class _OrbitGradientScaffoldMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final action = snackBar.action;
    return super.showSnackBar(
      SnackBar(
        key: snackBar.key,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            key: const Key('orbit_gradient_snackbar'),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[AppColors.primaryStart, AppColors.primaryEnd],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: DefaultTextStyle.merge(
                style: AppTypography.body.copyWith(color: AppColors.white),
                child: IconTheme.merge(
                  data: const IconThemeData(color: AppColors.white),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Expanded(child: snackBar.content),
                      if (action != null) ...<Widget>[
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: action.onPressed,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.white,
                          ),
                          child: Text(action.label),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: snackBar.width == null
            ? (snackBar.margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 16))
            : null,
        width: snackBar.width,
        duration: snackBar.duration,
        onVisible: snackBar.onVisible,
        showCloseIcon: snackBar.showCloseIcon,
        closeIconColor: AppColors.white,
        dismissDirection: snackBar.dismissDirection,
      ),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}
