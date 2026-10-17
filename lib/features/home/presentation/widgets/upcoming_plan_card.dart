import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/home_models.dart';
import 'home_media_image.dart';

class UpcomingPlanCard extends StatelessWidget {
  const UpcomingPlanCard({required this.data, required this.onTap, super.key});

  final UpcomingPlanData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const icon = SizedBox(
      width: 40,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x1FA576F6),
        ),
        child: Icon(
          Icons.groups_2_outlined,
          size: 22,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
    const forward = Icon(
      Icons.chevron_right_rounded,
      size: 22,
      color: Color(0xFF7C3AED),
    );

    final information = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          data.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F1724),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.location_on_outlined,
              size: 13,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                data.schedule,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F1724),
                ),
              ),
            ),
          ],
        ),
        if (data.location != null && data.location!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            data.location!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ],
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep the full participant stack but move it below the title on
              // compact devices instead of squeezing / truncating all details.
              final compact = constraints.maxWidth < 345;
              if (compact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: information),
                        const SizedBox(width: 5),
                        forward,
                      ],
                    ),
                    if (data.participants.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _ParticipantStack(
                          participants: data.participants,
                        ),
                      ),
                    ],
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: information),
                  if (data.participants.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 8),
                    _ParticipantStack(participants: data.participants),
                  ],
                  const SizedBox(width: 6),
                  forward,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ParticipantStack extends StatelessWidget {
  const _ParticipantStack({required this.participants});

  static const double _avatarSize = 28;
  static const double _overlap = 9;
  static const int _maxVisible = 3;

  final List<ParticipantData> participants;

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.min(participants.length, _maxVisible);
    final overflowCount = participants.length - visibleCount;
    final chipCount = visibleCount + (overflowCount > 0 ? 1 : 0);
    final width = _avatarSize + (chipCount - 1) * (_avatarSize - _overlap);

    return SizedBox(
      width: width,
      height: _avatarSize,
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < visibleCount; index++)
            Positioned(
              left: index * (_avatarSize - _overlap),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: HomeAvatar(
                    imagePath: participants[index].imagePath,
                    name: participants[index].name,
                    size: _avatarSize - 2,
                  ),
                ),
              ),
            ),
          if (overflowCount > 0)
            Positioned(
              left: visibleCount * (_avatarSize - _overlap),
              child: Container(
                width: _avatarSize,
                height: _avatarSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEDE9FE),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflowCount',
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
