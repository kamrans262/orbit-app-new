import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/orbit_models.dart';

class OrbitPersonAvatar extends StatelessWidget {
  const OrbitPersonAvatar({
    required this.person,
    this.size = 68,
    this.showNewBadge = true,
    super.key,
  });

  final OrbitPersonData person;
  final double size;
  final bool showNewBadge;

  static const double badgeOverlap = 10;

  @override
  Widget build(BuildContext context) {
    final badgeVisible = showNewBadge && person.isNew;

    // When this widget is used in the people strip, always reserve the badge
    // overlap area. That keeps every person's name on the same baseline even
    // when only some backend records are marked as new.
    final reservedHeight = showNewBadge ? size + badgeOverlap : size;

    return SizedBox(
      width: size,
      height: reservedHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          SizedBox.square(
            dimension: size,
            child: ClipOval(
              child: _OrbitAvatarImage(
                imagePath: person.imagePath,
                name: person.name,
              ),
            ),
          ),
          if (badgeVisible)
            Positioned(
              top: size - badgeOverlap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrbitAvatarImage extends StatelessWidget {
  const _OrbitAvatarImage({required this.imagePath, required this.name});

  final String? imagePath;
  final String name;

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();
    if (path == null || path.isEmpty) {
      return _AvatarFallback(name: name);
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => _AvatarFallback(name: name),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();

    return ColoredBox(
      color: const Color(0xFFF1ECFE),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }
}
