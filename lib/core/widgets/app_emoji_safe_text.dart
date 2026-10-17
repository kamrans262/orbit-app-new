import 'package:flutter/material.dart';

/// Renders a small set of decorative app emoji as Material icons so the UI
/// never depends on Poppins or the device emoji font.
///
/// Call sites should prefer ASCII-only Dart unicode escapes (for example
/// `\u{1F44B}`) in source. That prevents Windows text tooling from corrupting
/// literal UTF-8 emoji bytes before this widget receives them.
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
      icon: Icons.wb_twilight_rounded,
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
      if (textBuffer.isEmpty) return;
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
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              spec.icon,
              semanticLabel: spec.semanticLabel,
              size: baseFontSize * 1.02,
              color: spec.color ?? style?.color,
            ),
          ),
        ),
      );

      // A variation selector immediately after a mapped symbol belongs to the
      // same symbol and should not become stray text.
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
