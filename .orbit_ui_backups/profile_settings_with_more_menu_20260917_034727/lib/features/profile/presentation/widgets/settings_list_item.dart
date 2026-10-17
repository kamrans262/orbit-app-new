import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

/// Shared row used by the Profile / Settings card.
///
/// The 42px icon/row rhythm and 17px text gap are taken from the current
/// Settings Figma. The row can grow vertically when localized/backend text
/// needs a second line, so the layout remains overflow-safe.
class SettingsListItem extends StatelessWidget {
  const SettingsListItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconWidget,
    super.key,
  });

  static const double iconCircleSize = 42;
  static const double iconToLabelGap = 17;

  final IconData icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: iconCircleSize),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x1FA576F6),
                  ),
                  child: SizedBox.square(
                    dimension: iconCircleSize,
                    child: Center(
                      child:
                          iconWidget ??
                          Icon(icon, size: 24, color: const Color(0xFF7C3AED)),
                    ),
                  ),
                ),
                const SizedBox(width: iconToLabelGap),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F1724),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
