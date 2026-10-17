import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';

class AuthPasswordVisibilityButton extends StatelessWidget {
  const AuthPasswordVisibilityButton({
    required this.obscurePassword,
    required this.onPressed,
    this.buttonKey,
    this.color = AppColors.textMuted,
    super.key,
  });

  final bool obscurePassword;
  final VoidCallback onPressed;
  final Key? buttonKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscurePassword ? 'Show password' : 'Hide password',
      child: InkWell(
        key: buttonKey,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(23),
        child: SizedBox.square(
          dimension: AppTextField.referenceHeight,
          child: Icon(
            obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 19,
            color: color,
          ),
        ),
      ),
    );
  }
}
