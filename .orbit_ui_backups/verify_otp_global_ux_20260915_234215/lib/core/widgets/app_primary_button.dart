import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  static const double maxHeight = 54;
  static const double minHeight = 50;
  static const double radius = 30;

  final String label;
  final VoidCallback onPressed;

  static double heightFor(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return (viewportHeight * 0.064).clamp(minHeight, maxHeight).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final buttonHeight = heightFor(context);

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: AppColors.buttonShadow,
                offset: Offset(0, 4),
                blurRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14.1, sigmaY: 14.1),
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        AppColors.primaryStart,
                        AppColors.primaryEnd,
                      ],
                    ),
                  ),
                  child: InkWell(
                    onTap: onPressed,
                    child: Center(
                      child: Text(
                        label,
                        style: AppTypography.button.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
