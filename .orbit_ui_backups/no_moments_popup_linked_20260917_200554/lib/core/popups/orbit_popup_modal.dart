import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import '../widgets/app_primary_button.dart';

abstract final class OrbitPopupTokens {
  static const Color darkText = Color(0xFF0F1724);
  static const Color mutedText = Color(0xFF9CA3AF);
  static const Color secondaryText = Color(0xFFA0A7B3);
  static const Color accentStart = Color(0xFFC857D6);
  static const Color accentEnd = Color(0xFF7C5CFC);
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[accentStart, accentEnd],
  );

  static const double horizontalScreenMargin = 24;
  static const double maxWidth = 300;
  static const double radius = 12;
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(24, 32, 24, 24);
}

Future<T?> showOrbitPopupModal<T>({
  required BuildContext context,
  required Widget Function(BuildContext dialogContext) builder,
  bool barrierDismissible = false,
  Duration transitionDuration = const Duration(milliseconds: 180),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Orbit popup',
    barrierColor: Colors.transparent,
    transitionDuration: transitionDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        minimum: const EdgeInsets.all(OrbitPopupTokens.horizontalScreenMargin),
        child: Center(child: builder(dialogContext)),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scale = Tween<double>(begin: 0.96, end: 1).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

class OrbitPopupModal extends StatelessWidget {
  const OrbitPopupModal({
    required this.title,
    required this.primaryAction,
    this.icon,
    this.description,
    this.metadata,
    this.content,
    this.secondaryAction,
    this.maxWidth = OrbitPopupTokens.maxWidth,
    this.iconToTitleGap = 20,
    this.titleToDescriptionGap = 14,
    this.sectionGap = 24,
    this.contentToPrimaryGap = 20,
    this.primaryToSecondaryGap = 8,
    super.key,
  });

  final String title;
  final Widget primaryAction;
  final Widget? icon;
  final String? description;
  final Widget? metadata;
  final Widget? content;
  final Widget? secondaryAction;
  final double maxWidth;
  final double iconToTitleGap;
  final double titleToDescriptionGap;
  final double sectionGap;
  final double contentToPrimaryGap;
  final double primaryToSecondaryGap;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeHeight =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        (OrbitPopupTokens.horizontalScreenMargin * 2);
    final maxHeight = safeHeight > 1 ? safeHeight : 1.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(OrbitPopupTokens.radius),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              offset: Offset(0, 20),
              blurRadius: 60,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OrbitPopupTokens.radius),
          child: SingleChildScrollView(
            key: const Key('orbit_popup_scroll_view'),
            physics: const BouncingScrollPhysics(),
            padding: OrbitPopupTokens.contentPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Center(child: icon),
                  SizedBox(height: iconToTitleGap),
                ],
                Text(
                  title,
                  key: const Key('orbit_popup_title'),
                  textAlign: TextAlign.center,
                  style: AppTypography.smallHeading.copyWith(
                    color: OrbitPopupTokens.darkText,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                if (description != null &&
                    description!.trim().isNotEmpty) ...<Widget>[
                  SizedBox(height: titleToDescriptionGap),
                  Text(
                    description!,
                    key: const Key('orbit_popup_description'),
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: OrbitPopupTokens.mutedText,
                      fontSize: 14,
                      height: 21.7 / 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                if (metadata != null) ...<Widget>[
                  SizedBox(height: sectionGap),
                  metadata!,
                ],
                if (content != null) ...<Widget>[
                  SizedBox(height: sectionGap),
                  content!,
                ],
                SizedBox(height: contentToPrimaryGap),
                primaryAction,
                if (secondaryAction != null) ...<Widget>[
                  SizedBox(height: primaryToSecondaryGap),
                  secondaryAction!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OrbitPopupPrimaryButton extends StatelessWidget {
  const OrbitPopupPrimaryButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: AppPrimaryButton(label: label, onPressed: onPressed),
        ),
      ),
    );
  }
}

class OrbitSecondaryTextButton extends StatelessWidget {
  const OrbitSecondaryTextButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: OrbitPopupTokens.secondaryText,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
