import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../circles/presentation/widgets/overlapping_avatar_stack.dart';
import '../../domain/models/explore_models.dart';
import 'explore_media_image.dart';

class ExploreMeetupCard extends StatelessWidget {
  const ExploreMeetupCard({
    required this.data,
    required this.isSaved,
    required this.isJoined,
    required this.onTap,
    required this.onSave,
    required this.onJoin,
    super.key,
  });

  final ExploreMeetupData data;
  final bool isSaved;
  final bool isJoined;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1EFFB),
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth;
              final imageSize = (available * 0.25).clamp(70.0, 82.0).toDouble();
              final actionWidth = (available * 0.22).clamp(58.0, 70.0).toDouble();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox.square(
                      dimension: imageSize,
                      child: ExploreMediaImage(path: data.image),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MeetupInfo(data: data),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: actionWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topRight,
                          child: AppCircularIconButton(
                            semanticLabel: isSaved ? 'Remove bookmark' : 'Save meetup',
                            onPressed: onSave,
                            size: 32,
                            iconSize: 18,
                            icon: isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            iconColor: const Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _JoinButton(
                          joined: isJoined,
                          onPressed: onJoin,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MeetupInfo extends StatelessWidget {
  const _MeetupInfo({required this.data});

  final ExploreMeetupData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          data.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontFamilyFallback: <String>[AppTypography.fontFamily],
            fontSize: 16,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          data.dateTimeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _detailStyle,
        ),
        const SizedBox(height: 3),
        Text(
          data.secondaryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _detailStyle,
        ),
        const SizedBox(height: 9),
        Row(
          children: <Widget>[
            Flexible(
              child: OverlappingAvatarStack(
                avatars: data.attendeeAvatars,
                memberCount: data.attendeeCount,
                maxVisible: 3,
                avatarSize: 28,
                borderColor: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                '${data.attendeeCount} going',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _detailStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const TextStyle _detailStyle = TextStyle(
    fontFamily: 'Montserrat',
    fontFamilyFallback: <String>[AppTypography.fontFamily],
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
    color: Color(0xFF8E9196),
  );
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.joined, required this.onPressed});

  final bool joined;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: joined ? 'Joined' : 'Join',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFFC857D6),
              Color(0xFF7C5CFC),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              child: Text(
                joined ? 'Joined' : 'Join',
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
