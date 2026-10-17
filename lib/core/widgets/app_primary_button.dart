import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  static const double maxHeight = 54;
  static const double minHeight = 50;
  static const double radius = 30;
  static const Color disabledBackground = Color(0xFFECECEC);
  static const Color disabledText = Color(0xFF9E9E9E);

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  static double heightFor(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return (viewportHeight * 0.064).clamp(minHeight, maxHeight).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final buttonHeight = heightFor(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: enabled
              ? _EnabledPrimaryButton(
                  key: const ValueKey<String>('primary_enabled'),
                  label: label,
                  onPressed: onPressed,
                )
              : _DisabledPrimaryButton(
                  key: const ValueKey<String>('primary_disabled'),
                  label: label,
                ),
        ),
      ),
    );
  }
}

class _EnabledPrimaryButton extends StatelessWidget {
  const _EnabledPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppPrimaryButton.radius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.buttonShadow,
            offset: Offset(0, 4),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppPrimaryButton.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14.1, sigmaY: 14.1),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[AppColors.primaryStart, AppColors.primaryEnd],
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
    );
  }
}

class _DisabledPrimaryButton extends StatelessWidget {
  const _DisabledPrimaryButton({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPrimaryButton.disabledBackground,
        borderRadius: BorderRadius.circular(AppPrimaryButton.radius),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.button.copyWith(
            color: AppPrimaryButton.disabledText,
          ),
        ),
      ),
    );
  }
}
