import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

class OverlappingAvatarStack extends StatelessWidget {
  const OverlappingAvatarStack({
    required this.avatars,
    required this.memberCount,
    required this.maxVisible,
    this.avatarSize = 36,
    super.key,
  });

  final List<String?> avatars;
  final int memberCount;
  final int maxVisible;
  final double avatarSize;

  static const double _overlap = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (memberCount <= 0 || maxVisible <= 0) {
          return const SizedBox.shrink();
        }

        final double step = math.max(avatarSize - _overlap, 1.0).toDouble();
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : avatarSize + step * (maxVisible > 1 ? maxVisible - 1 : 0);
        final int capacity = width <= avatarSize
            ? 1
            : ((width - avatarSize) / step).floor() + 1;
        final int cappedCapacity = capacity < maxVisible
            ? capacity
            : maxVisible;
        final int slotCount = cappedCapacity < 1 ? 1 : cappedCapacity;
        final bool needsOverflow = memberCount > slotCount;
        final int avatarSlots = needsOverflow
            ? (slotCount > 1 ? slotCount - 1 : 0)
            : slotCount;
        final int availableAvatarCount = avatarSlots < memberCount
            ? avatarSlots
            : memberCount;
        final int hiddenCount = memberCount > availableAvatarCount
            ? memberCount - availableAvatarCount
            : 0;
        final int visibleBubbleCount =
            availableAvatarCount + (needsOverflow ? 1 : 0);
        final stackWidth =
            avatarSize + step * math.max(visibleBubbleCount - 1, 0).toDouble();

        return SizedBox(
          width: math.min(stackWidth, width).toDouble(),
          height: avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (var index = 0; index < availableAvatarCount; index++)
                Positioned(
                  left: index * step,
                  child: _AvatarBubble(
                    imagePath: index < avatars.length ? avatars[index] : null,
                    size: avatarSize,
                    fallbackLabel: '${index + 1}',
                  ),
                ),
              if (needsOverflow)
                Positioned(
                  left: availableAvatarCount * step,
                  child: _CountBubble(count: hiddenCount, size: avatarSize),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.imagePath,
    required this.size,
    required this.fallbackLabel,
  });

  final String? imagePath;
  final double size;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: _AvatarImage(imagePath: imagePath, fallbackLabel: fallbackLabel),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.imagePath, required this.fallbackLabel});

  final String? imagePath;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();
    if (path == null || path.isEmpty) {
      return _AvatarFallback(label: fallbackLabel);
    }

    final fallback = _AvatarFallback(label: fallbackLabel);
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2EAFE),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }
}

class _CountBubble extends StatelessWidget {
  const _CountBubble({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2EAFE),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '+$count',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: const <String>[
            'Noto Color Emoji',
            'Apple Color Emoji',
            'Segoe UI Emoji',
          ],
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}
