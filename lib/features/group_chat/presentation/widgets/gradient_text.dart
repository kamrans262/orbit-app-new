import 'package:flutter/material.dart';

import '../../../../core/chat/chat_rich_text.dart';

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    required this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  static const LinearGradient appGradient = LinearGradient(
    colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => appGradient.createShader(bounds),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: style.copyWith(
          color: Colors.white,
          fontFamilyFallback: ChatRichText.emojiFontFallback,
        ),
      ),
    );
  }
}
