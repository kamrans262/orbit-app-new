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
    this.trailing,
    super.key,
  });

  static const double iconCircleSize = 42;
  static const double iconToLabelGap = 17;

  final IconData icon;
  final Widget? iconWidget;
  final Widget? trailing;
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
                trailing ?? const Icon(
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


/// Identical white rounded/shadowed surface used by Profile → Settings.
/// Other profile sections (including a friend's Quick Actions) can use the
/// existing SettingsListItem geometry without inventing another card style.
class SettingsListCard extends StatelessWidget {
  const SettingsListCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 2),
            blurRadius: 7,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var index = 0; index < children.length; index++) ...<Widget>[
              children[index],
              if (index != children.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
