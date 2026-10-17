import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0xFFD8D8D8)),
        ),
        SizedBox(width: 12),
        Text(
          'or continue with',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0xFFD8D8D8)),
        ),
      ],
    );
  }
}
