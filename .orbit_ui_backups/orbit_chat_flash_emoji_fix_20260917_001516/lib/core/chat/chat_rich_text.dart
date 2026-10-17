import 'package:flutter/material.dart';

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

  static final Map<String, IconData> _inlineIcons = <String, IconData>{
    '\u{1F30A}': Icons.waves_rounded,
    '\u{2615}': Icons.local_cafe_rounded,
    '\u{1F601}': Icons.sentiment_very_satisfied_rounded,
    '\u{1F389}': Icons.celebration_rounded,
    '\u{1F3D6}\u{FE0F}': Icons.beach_access_rounded,
    '\u{1F919}': Icons.waving_hand_rounded,
    '\u{2764}\u{FE0F}': Icons.favorite_rounded,
    '\u{1F44D}': Icons.thumb_up_rounded,
    '\u{1F44E}': Icons.thumb_down_rounded,
    '\u{1F602}': Icons.sentiment_very_satisfied_rounded,
    '\u{1F62E}': Icons.sentiment_neutral,
    '\u{1F622}': Icons.sentiment_dissatisfied_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans(text, style);
    return Text.rich(
      TextSpan(children: spans, style: style),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  static List<InlineSpan> _buildSpans(String source, TextStyle style) {
    if (source.isEmpty) return const <InlineSpan>[];
    final result = <InlineSpan>[];
    var cursor = 0;
    while (cursor < source.length) {
      var bestIndex = -1;
      String? bestToken;
      for (final token in _inlineIcons.keys) {
        final index = source.indexOf(token, cursor);
        if (index >= 0 && (bestIndex < 0 || index < bestIndex)) {
          bestIndex = index;
          bestToken = token;
        }
      }
      if (bestIndex < 0 || bestToken == null) {
        result.add(TextSpan(text: source.substring(cursor)));
        break;
      }
      if (bestIndex > cursor) {
        result.add(TextSpan(text: source.substring(cursor, bestIndex)));
      }
      final icon = _inlineIcons[bestToken]!;
      final fontSize = style.fontSize ?? 14;
      result.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              icon,
              size: fontSize * 1.05,
              color: style.color ?? const Color(0xFF0F1724),
            ),
          ),
        ),
      );
      cursor = bestIndex + bestToken.length;
    }
    return result;
  }
}
