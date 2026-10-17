import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import 'orbit_popup_modal.dart';

class OrbitPopupHeaderIcon extends StatelessWidget {
  const OrbitPopupHeaderIcon({
    required this.child,
    this.size = 54,
    super.key,
  });

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(child: child),
    );
  }
}

class OrbitPopupInfoSection extends StatelessWidget {
  const OrbitPopupInfoSection({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F5FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class OrbitVersionBadge extends StatelessWidget {
  const OrbitVersionBadge({
    required this.label,
    required this.emphasized,
    super.key,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? const Color(0xFFF1EAFE) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w600,
            color: emphasized
                ? OrbitPopupTokens.accentEnd
                : const Color(0xFF9AA3B2),
          ),
        ),
      ),
    );
  }
}

class OrbitGradientBullet extends StatelessWidget {
  const OrbitGradientBullet({this.size = 6, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: OrbitPopupTokens.accentGradient,
        ),
      ),
    );
  }
}

class OrbitGradientText extends StatelessWidget {
  const OrbitGradientText({
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => OrbitPopupTokens.accentGradient.createShader(bounds),
      child: Text(text, textAlign: textAlign, style: style.copyWith(color: Colors.white)),
    );
  }
}
