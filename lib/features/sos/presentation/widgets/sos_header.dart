import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';

class SosHeader extends StatelessWidget {
  const SosHeader({required this.onBack, required this.onClose, super.key});

  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: _HeaderIconButton(
              semanticLabel: 'Back',
              onTap: onBack,
              icon: Icons.arrow_back_ios_new_rounded,
              iconColor: Colors.white,
            ),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'EMERGENCY',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Color(0xFFF44336),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'SOS Alert',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _HeaderIconButton(
              semanticLabel: 'Close',
              onTap: onClose,
              icon: Icons.close_rounded,
              iconColor: const Color(0xFFA9ADB6),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.semanticLabel,
    required this.onTap,
    required this.icon,
    required this.iconColor,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return AppCircularIconButton(
      semanticLabel: semanticLabel,
      onPressed: onTap,
      icon: icon,
      iconSize: 23,
      iconColor: iconColor,
      size: 40,
      // Keep the emergency screen's approved dark overlay treatment, but
      // use the same circular container, shadow and hit handling as Orbit.
      backgroundColor: const Color(0x1FFFFFFF),
    );
  }
}
