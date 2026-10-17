import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'app_primary_button.dart';

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  static const double radius = 30;

  final String label;
  final VoidCallback onPressed;

  static double heightFor(BuildContext context) {
    return AppPrimaryButton.heightFor(context);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: heightFor(context),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: AppTypography.button.copyWith(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
