import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

class SettingsListItem extends StatelessWidget {
  const SettingsListItem({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 2),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x1FA576F6),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(icon, size: 22, color: Color(0xFF7C3AED)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: const <String>[
                        'Noto Color Emoji',
                        'Apple Color Emoji',
                        'Segoe UI Emoji',
                      ],
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
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
