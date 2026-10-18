import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Poppins text can slightly exceed 320px devices with fixed 12px gaps.
        // Only compact screens reduce the gaps; normal-width layout is identical.
        final gap = constraints.maxWidth < 245 ? 4.0 : 12.0;
        return Row(
          children: <Widget>[
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0xFFD8D8D8)),
        ),
        SizedBox(width: gap),
        const Text(
          'or continue with',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0xFFD8D8D8)),
        ),
          ],
        );
      },
    );
  }
}
