import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import '../widgets/app_primary_button.dart';

abstract final class OrbitPopupTokens {
  static const Color darkText = Color(0xFF0F1724);
  static const Color mutedText = Color(0xFF9CA3AF);
  static const Color secondaryText = Color(0xFFA0A7B3);
  static const Color accentStart = Color(0xFFC857D6);
  static const Color accentEnd = Color(0xFF7C5CFC);
  static const Color destructive = Color(0xFFF44336);
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[accentStart, accentEnd],
  );

  // Reduced from the previous 24px outer screen margin so all 13 popups
  // sit wider on the device while keeping the popup's internal 24px padding.
  static const double horizontalScreenMargin = 16;
  static const double verticalScreenMargin = 12;
  static const double maxWidth = 430;
  static const double radius = 12;
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(24, 32, 24, 24);
}

final Set<String> _visibleOrbitPopupIds = <String>{};

Future<T?> showOrbitPopupModal<T>({
  required BuildContext context,
  required Widget Function(BuildContext dialogContext) builder,
  bool barrierDismissible = false,
  Duration transitionDuration = const Duration(milliseconds: 220),
  String? popupId,
}) async {
  if (popupId != null && !_visibleOrbitPopupIds.add(popupId)) {
    return null;
  }

  try {
    return await showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Orbit popup',
      barrierColor: Colors.transparent,
      transitionDuration: transitionDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          minimum: const EdgeInsets.symmetric(
            horizontal: OrbitPopupTokens.horizontalScreenMargin,
            vertical: OrbitPopupTokens.verticalScreenMargin,
          ),
          child: Center(child: builder(dialogContext)),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final media = MediaQuery.maybeOf(dialogContext);
        if (media?.disableAnimations ?? false) {
          return child;
        }

        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.97, end: 1).animate(curved);
        final translateY = Tween<double>(begin: 8, end: 0).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: scale,
            child: AnimatedBuilder(
              animation: translateY,
              child: child,
              builder: (context, staticChild) => Transform.translate(
                offset: Offset(0, translateY.value),
                child: staticChild,
              ),
            ),
          ),
        );
      },
    );
  } finally {
    if (popupId != null) {
      _visibleOrbitPopupIds.remove(popupId);
    }
  }
}

class OrbitPopupModal extends StatelessWidget {
  const OrbitPopupModal({
    required this.title,
    this.primaryAction,
    this.icon,
    this.description,
    this.metadata,
    this.content,
    this.secondaryAction,
    this.maxWidth = OrbitPopupTokens.maxWidth,
    this.iconToTitleGap = 20,
    this.titleToDescriptionGap = 20,
    this.sectionGap = 24,
    this.contentToPrimaryGap = 20,
    this.primaryToSecondaryGap = 8,
    this.showCloseButton = false,
    this.onClose,
    this.closeButtonKey,
    super.key,
  });

  final String title;
  final Widget? primaryAction;
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
  final bool showCloseButton;
  final VoidCallback? onClose;
  final Key? closeButtonKey;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeHeight =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        (OrbitPopupTokens.verticalScreenMargin * 2);
    final maxHeight = safeHeight > 1 ? safeHeight : 1.0;

    // MaterialType.transparency is intentional: it provides a proper Material
    // text context (avoiding debug yellow text decoration) without dimming or
    // recoloring the page underneath the transparent modal barrier.
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        key: const Key('orbit_popup_card'),
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
            child: Stack(
              children: <Widget>[
                SingleChildScrollView(
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
                          height: 1.3,
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
                      if (primaryAction != null) ...<Widget>[
                        SizedBox(height: contentToPrimaryGap),
                        primaryAction!,
                      ],
                      if (secondaryAction != null) ...<Widget>[
                        SizedBox(height: primaryToSecondaryGap),
                        secondaryAction!,
                      ],
                    ],
                  ),
                ),
                if (showCloseButton)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Semantics(
                      button: true,
                      label: 'Close popup',
                      child: GestureDetector(
                        key: closeButtonKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: onClose ?? () => Navigator.of(context).pop(),
                        child: const SizedBox.square(
                          dimension: 40,
                          child: Center(
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: OrbitPopupTokens.darkText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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

class OrbitPopupSecondaryButton extends StatelessWidget {
  const OrbitPopupSecondaryButton({
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
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF2EAF4),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.button.copyWith(
                  color: OrbitPopupTokens.accentEnd,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrbitPopupDestructiveButton extends StatelessWidget {
  const OrbitPopupDestructiveButton({
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
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OrbitPopupTokens.destructive,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.button.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrbitPopupTextButton extends StatelessWidget {
  const OrbitPopupTextButton({
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
        child: Semantics(
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
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: OrbitPopupTokens.secondaryText,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Backward-compatible name used by the existing Update Available popup.
class OrbitSecondaryTextButton extends OrbitPopupTextButton {
  const OrbitSecondaryTextButton({
    required super.label,
    required super.onPressed,
    super.key,
  });
}
