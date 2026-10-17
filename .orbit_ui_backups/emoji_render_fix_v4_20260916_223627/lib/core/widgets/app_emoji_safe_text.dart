import 'package:flutter/material.dart';

/// Renders the app's small set of decorative emoji as Material icons instead
/// of asking a bundled text font (Poppins) to provide emoji glyphs.
///
/// This is intentionally narrow: ordinary text remains untouched and keeps
/// the caller-provided typography. Unsupported emoji stay in the source text
/// so backend content is never silently deleted.
class AppEmojiSafeText extends StatelessWidget {
  const AppEmojiSafeText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool? softWrap;

  static const Map<int, _EmojiIconSpec> _iconByRune = <int, _EmojiIconSpec>{
    0x1F44B: _EmojiIconSpec(
      icon: Icons.waving_hand_rounded,
      semanticLabel: 'waving hand',
      color: Color(0xFFFFB547),
    ),
    0x1F305: _EmojiIconSpec(
      icon: Icons.wb_sunny_rounded,
      semanticLabel: 'sunset',
      color: Color(0xFFFFB547),
    ),
    0x1F3C3: _EmojiIconSpec(
      icon: Icons.directions_run_rounded,
      semanticLabel: 'running',
    ),
    0x2B50: _EmojiIconSpec(
      icon: Icons.star_rounded,
      semanticLabel: 'star',
      color: Color(0xFFFFB547),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _buildSpans()),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final textBuffer = StringBuffer();
    final runes = data.runes.toList(growable: false);

    void flushText() {
      if (textBuffer.isEmpty) {
        return;
      }
      spans.add(TextSpan(text: textBuffer.toString()));
      textBuffer.clear();
    }

    for (var index = 0; index < runes.length; index++) {
      final rune = runes[index];
      final spec = _iconByRune[rune];
      if (spec == null) {
        textBuffer.writeCharCode(rune);
        continue;
      }

      flushText();
      final baseFontSize = style?.fontSize ?? 14;
      final iconColor = spec.color ?? style?.color;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Semantics(
              label: spec.semanticLabel,
              child: ExcludeSemantics(
                child: Icon(
                  spec.icon,
                  size: baseFontSize * 1.02,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      );

      // Skip a variation selector that belongs to the mapped symbol.
      if (index + 1 < runes.length && runes[index + 1] == 0xFE0F) {
        index++;
      }
    }

    flushText();
    return spans;
  }
}

class _EmojiIconSpec {
  const _EmojiIconSpec({
    required this.icon,
    required this.semanticLabel,
    this.color,
  });

  final IconData icon;
  final String semanticLabel;
  final Color? color;
}
