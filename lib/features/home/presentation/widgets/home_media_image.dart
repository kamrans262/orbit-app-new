import 'package:flutter/material.dart';

class HomeMediaImage extends StatelessWidget {
  const HomeMediaImage({
    required this.path,
    required this.fit,
    this.alignment = Alignment.center,
    this.fallback,
    super.key,
  });

  final String path;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget? fallback;

  bool get _isNetwork =>
      path.startsWith('https://') || path.startsWith('http://');

  @override
  Widget build(BuildContext context) {
    final errorFallback =
        fallback ??
        const ColoredBox(
          color: Color(0xFFEFF1F5),
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF94A3B8),
            ),
          ),
        );

    if (path.trim().isEmpty) {
      return errorFallback;
    }

    if (_isNetwork) {
      return Image.network(
        path,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => errorFallback,
      );
    }

    return Image.asset(
      path,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => errorFallback,
    );
  }
}

class HomeAvatar extends StatelessWidget {
  const HomeAvatar({
    required this.imagePath,
    required this.name,
    required this.size,
    super.key,
  });

  final String imagePath;
  final String name;
  final double size;

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: HomeMediaImage(
          path: imagePath,
          fit: BoxFit.cover,
          fallback: ColoredBox(
            color: const Color(0xFFEDE9FE),
            child: Center(
              child: Text(
                _initial,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
