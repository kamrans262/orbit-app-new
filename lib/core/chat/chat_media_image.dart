import 'dart:io';

import 'package:flutter/material.dart';

class ChatMediaImage extends StatelessWidget {
  const ChatMediaImage({
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    super.key,
  });

  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty) return _fallback();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    return Image.file(
      File(value),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      constraints: const BoxConstraints(minHeight: 96),
      color: const Color(0xFFEAE7ED),
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFF94A3B8),
        size: 28,
      ),
    );
  }
}
