import 'package:flutter/material.dart';

class ExploreMediaImage extends StatelessWidget {
  const ExploreMediaImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
    super.key,
  });

  final String path;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) {
      return _Fallback(icon: fallbackIcon);
    }

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return Image.network(
        cleanPath,
        fit: fit,
        errorBuilder: (_, __, ___) => _Fallback(icon: fallbackIcon),
      );
    }

    return Image.asset(
      cleanPath,
      fit: fit,
      errorBuilder: (_, __, ___) => _Fallback(icon: fallbackIcon),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEDEAF8),
      child: Center(
        child: Icon(icon, color: const Color(0xFF7C5CFC), size: 28),
      ),
    );
  }
}
