import 'package:flutter/material.dart';

/// Rich chat text that keeps the app typeface for normal text while delegating
/// emoji glyphs to the platform/system emoji fonts.
class ChatRichText extends StatelessWidget {
  const ChatRichText(
    this.text, {
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  static const List<String> emojiFontFallback = <String>[
    'Noto Color Emoji',
    'Samsung Color Emoji',
    'Segoe UI Emoji',
    'Apple Color Emoji',
  ];

  // Longest tokens first so variants such as ❤️ and 🏖️ are consumed as one
  // visual glyph rather than leaving a variation selector behind.
  static const List<String> _emojiTokens = <String>[
    '\u{2764}\u{FE0F}', // ❤️
    '\u{1F3D6}\u{FE0F}', // 🏖️
    '\u{1F30A}', // 🌊
    '\u{2615}', // ☕
    '\u{1F389}', // 🎉
    '\u{1F44D}', // 👍
    '\u{1F44E}', // 👎
    '\u{1F602}', // 😂
    '\u{1F62E}', // 😮
    '\u{1F622}', // 😢
    '\u{1F601}', // 😁
    '\u{1F919}', // 🤙
    '\u{1F525}', // 🔥
  ];

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _buildSpans(text), style: style),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<InlineSpan> _buildSpans(String source) {
    if (source.isEmpty) return const <InlineSpan>[];

    final spans = <InlineSpan>[];
    var cursor = 0;
    while (cursor < source.length) {
      var nextIndex = -1;
      String? nextEmoji;

      for (final emoji in _emojiTokens) {
        final index = source.indexOf(emoji, cursor);
        if (index >= 0 && (nextIndex < 0 || index < nextIndex)) {
          nextIndex = index;
          nextEmoji = emoji;
        }
      }

      if (nextIndex < 0 || nextEmoji == null) {
        spans.add(TextSpan(text: source.substring(cursor)));
        break;
      }

      if (nextIndex > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, nextIndex)));
      }

      spans.add(_emojiSpan(nextEmoji));
      cursor = nextIndex + nextEmoji.length;
    }

    return spans;
  }

  InlineSpan _emojiSpan(String emoji) {
    final fontSize = style.fontSize ?? 14;
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Text(
        emoji,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: fontSize,
          height: 1,
          fontFamilyFallback: emojiFontFallback,
        ),
      ),
    );
  }
}
