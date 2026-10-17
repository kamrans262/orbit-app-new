import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

class AuthAccountSwitch extends StatelessWidget {
  const AuthAccountSwitch({
    required this.prompt,
    required this.actionLabel,
    required this.onActionPressed,
    this.actionKey,
    super.key,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: <Widget>[
        Text(
          prompt,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
        Semantics(
          button: true,
          label: actionLabel,
          child: GestureDetector(
            key: actionKey,
            behavior: HitTestBehavior.opaque,
            onTap: onActionPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
