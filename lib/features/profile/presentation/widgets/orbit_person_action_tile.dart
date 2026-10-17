import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

/// Shared Orbit person card used by privacy/blocking and circle invite flows.
///
/// Keeping avatar geometry, name styling, card radius and internal alignment in
/// one widget prevents the person rows from drifting visually across screens.
class OrbitPersonActionTile extends StatelessWidget {
  const OrbitPersonActionTile({
    required this.name,
    required this.avatarSource,
    required this.trailing,
    this.onTap,
    this.containerKey,
    this.avatarKey,
    this.semanticLabel,
    super.key,
  });

  static const double referenceHeight = 67;
  static const double radius = 30;
  static const double avatarExtent = 50;
  static const double avatarToNameGap = 6;

  final String name;
  final String avatarSource;
  final Widget trailing;
  final VoidCallback? onTap;
  final Key? containerKey;
  final Key? avatarKey;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      key: containerKey,
      constraints: const BoxConstraints(minHeight: referenceHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: <Widget>[
              OrbitPersonAvatar(
                key: avatarKey,
                source: avatarSource,
                name: name,
              ),
              const SizedBox(width: avatarToNameGap),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      ),
    );

    final callback = onTap;
    if (callback == null) {
      return card;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: callback,
        child: card,
      ),
    );
  }
}

class OrbitPersonAvatar extends StatelessWidget {
  const OrbitPersonAvatar({
    required this.source,
    required this.name,
    super.key,
  });

  final String source;
  final String name;

  @override
  Widget build(BuildContext context) {
    final fallback = _AvatarFallback(name: name);
    Widget image;

    if (source.startsWith('http://') || source.startsWith('https://')) {
      image = Image.network(
        source,
        width: OrbitPersonActionTile.avatarExtent,
        height: OrbitPersonActionTile.avatarExtent,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      );
    } else if (source.trim().isNotEmpty) {
      image = Image.asset(
        source,
        width: OrbitPersonActionTile.avatarExtent,
        height: OrbitPersonActionTile.avatarExtent,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else {
      image = fallback;
    }

    return Container(
      width: OrbitPersonActionTile.avatarExtent,
      height: OrbitPersonActionTile.avatarExtent,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(child: image),
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
        : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: OrbitPersonActionTile.avatarExtent,
      height: OrbitPersonActionTile.avatarExtent,
      color: const Color(0xFFF2EAFE),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}
