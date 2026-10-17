import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class AppActionRow extends StatelessWidget {
  const AppActionRow({
    required this.leadingIcon,
    required this.iconBackgroundColor,
    required this.leadingIconColor,
    required this.title,
    this.containerKey,
    this.iconCircleKey,
    this.toggleKey,
    this.toggleTrackKey,
    this.toggleValue,
    this.onToggleChanged,
    this.trailing,
    this.onTap,
    super.key,
  }) : assert(
         toggleValue == null || onToggleChanged != null,
         'onToggleChanged is required when toggleValue is provided.',
       ),
       assert(
         toggleValue == null || trailing == null,
         'Use either the built-in toggle or a custom trailing widget.',
       );

  static const double referenceHeight = 68;
  static const double compactMinHeight = 62;
  static const double radius = 30;
  static const double horizontalPadding = 16;
  static const double iconSize = 36;
  static const double iconToTitleGap = 16;

  final IconData leadingIcon;
  final Color iconBackgroundColor;
  final Color leadingIconColor;
  final String title;
  final Key? containerKey;
  final Key? iconCircleKey;
  final Key? toggleKey;
  final Key? toggleTrackKey;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggleChanged;
  final Widget? trailing;
  final VoidCallback? onTap;

  static double heightFor(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return (viewportHeight * 0.0806)
        .clamp(compactMinHeight, referenceHeight)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final trailingWidget = toggleValue != null
        ? _AppActionToggle(
            key: toggleKey,
            trackKey: toggleTrackKey,
            value: toggleValue!,
            onChanged: onToggleChanged!,
          )
        : trailing;

    return SizedBox(
      key: containerKey,
      height: heightFor(context),
      width: double.infinity,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: <Widget>[
                Container(
                  key: iconCircleKey,
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(leadingIcon, size: 22, color: leadingIconColor),
                ),
                const SizedBox(width: iconToTitleGap),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F1724),
                    ),
                  ),
                ),
                if (trailingWidget != null) ...<Widget>[
                  const SizedBox(width: 12),
                  trailingWidget,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppActionToggle extends StatelessWidget {
  const _AppActionToggle({
    required this.trackKey,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Key? trackKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      label: value ? 'Permission enabled' : 'Permission disabled',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: AnimatedContainer(
                key: trackKey,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                width: 24,
                height: 14,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: value
                      ? const Color(0xFF9A48EA)
                      : const Color(0xFFD4D4D4),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: 10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
