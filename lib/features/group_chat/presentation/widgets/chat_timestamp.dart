import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

class ChatTimestamp extends StatelessWidget {
  const ChatTimestamp(this.value, {this.alignment = TextAlign.left, super.key});

  final String value;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: alignment,
      maxLines: 1,
      style: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w400,
        color: Color(0x61000000),
      ),
    );
  }
}
