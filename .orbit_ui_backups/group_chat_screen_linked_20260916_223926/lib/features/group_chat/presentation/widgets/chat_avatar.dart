import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    required this.name,
    this.imagePath,
    this.size = 32,
    super.key,
  });

  final String name;
  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: path == null || path.isEmpty
            ? _Fallback(name: name)
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _Fallback(name: name),
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    return ColoredBox(
      color: const Color(0xFFE9DDFD),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }
}
