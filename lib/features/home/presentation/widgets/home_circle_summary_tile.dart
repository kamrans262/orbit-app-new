import 'package:flutter/material.dart';

import '../../domain/models/home_models.dart';
import 'home_circle_avatar_tile.dart';

/// Render M5 Circle metadata using the original approved Home circular
/// avatar tile — not a newly designed rectangular card.
/// This is presentation-only: an M5 Circle never becomes an M4 friendship.
class HomeCircleSummaryTile extends StatelessWidget {
  const HomeCircleSummaryTile({
    required this.data,
    required this.onTap,
    super.key,
  });

  final HomeCircleSummaryData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final memberLabel = data.memberCount == 1
        ? '1 member'
        : '${data.memberCount} members';

    return Semantics(
      label: '${data.name}, ${memberLabel}, open Circle',
      button: true,
      child: HomeCircleAvatarTile(
        data: FavoritePersonData(
          id: data.id,
          name: data.name,
          status: memberLabel,
          imagePath: '',
          // Presence is unknown, so never display an online/offline dot.
          isOnline: null,
        ),
        onTap: onTap,
      ),
    );
  }
}
