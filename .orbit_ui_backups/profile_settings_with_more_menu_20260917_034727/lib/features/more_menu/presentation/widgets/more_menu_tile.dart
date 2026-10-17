import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

class MoreMenuTile extends StatelessWidget {
  const MoreMenuTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.onTap,
    this.titleColor = const Color(0xFF0F1724),
    this.containerKey,
    this.iconCircleKey,
    this.titleKey,
    this.chevronKey,
    super.key,
  });

  static const double referenceHeight = 67;
  static const double radius = 30;
  static const double iconDiameter = 42;
  static const double iconSize = 22;
  static const double horizontalPadding = 12;
  static const double verticalPadding = 12.5;
  static const double iconToTitleGap = 12;

  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final Color titleColor;
  final VoidCallback onTap;
  final Key? containerKey;
  final Key? iconCircleKey;
  final Key? titleKey;
  final Key? chevronKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: ConstrainedBox(
        key: containerKey,
        constraints: const BoxConstraints(minHeight: referenceHeight),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Row(
                  children: <Widget>[
                    DecoratedBox(
                      key: iconCircleKey,
                      decoration: BoxDecoration(
                        color: iconBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: iconDiameter,
                        child: Center(
                          child: Icon(icon, size: iconSize, color: iconColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: iconToTitleGap),
                    Expanded(
                      child: Text(
                        title,
                        key: titleKey,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.chevron_right_rounded,
                      key: chevronKey,
                      size: 24,
                      color: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
