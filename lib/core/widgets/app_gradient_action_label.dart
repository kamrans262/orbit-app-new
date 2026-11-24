import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Applies Orbit's approved gradient only to a normally enabled Material
/// text action. Preserve the inherited typography, disabled state, and any
/// intentionally different foreground color.
class AppGradientActionLabel extends StatelessWidget {
  const AppGradientActionLabel(
    this.data, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final text = Text(data, style: style, textAlign: textAlign,
        maxLines: maxLines, overflow: overflow);
    final effective = inherited.merge(style);
    if (effective.color != Theme.of(context).colorScheme.primary ||
        effective.foreground != null) {
      return text;
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: AppColors.primaryGradient.createShader,
      child: text,
    );
  }
}
