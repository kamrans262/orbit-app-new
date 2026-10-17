import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/group_chat_models.dart';

class OverlappingParticipantAvatars extends StatelessWidget {
  const OverlappingParticipantAvatars({
    required this.participants,
    required this.memberCount,
    this.maxVisible = 3,
    this.avatarSize = 36,
    super.key,
  });

  final List<GroupParticipant> participants;
  final int memberCount;
  final int maxVisible;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.min(participants.length, math.max(0, maxVisible));
    final hiddenCount = math.max(0, memberCount - visibleCount);
    final overlap = avatarSize * 0.30;
    final step = avatarSize - overlap;
    final totalItems = visibleCount + (hiddenCount > 0 ? 1 : 0);
    final width = totalItems == 0
        ? avatarSize
        : avatarSize + ((totalItems - 1) * step);

    return SizedBox(
      height: avatarSize,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var index = 0; index < visibleCount; index++)
            Positioned(
              left: index * step,
              child: _ParticipantAvatar(
                participant: participants[index],
                size: avatarSize,
              ),
            ),
          if (hiddenCount > 0)
            Positioned(
              left: visibleCount * step,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x66FFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '+$hiddenCount',
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.participant, required this.size});

  final GroupParticipant participant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = participant.avatarPath?.trim();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: path == null || path.isEmpty
            ? _AvatarFallback(name: participant.name)
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(name: participant.name),
              ),
      ),
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
    return ColoredBox(
      color: const Color(0xFFB993F7),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
