import 'package:flutter/material.dart';

import '../../../circles/domain/models/friend_details_models.dart';
import '../../../circles/presentation/widgets/circle_group_card.dart';
import '../../domain/models/home_models.dart';

/// M8 adapter to the ORIGINAL My Circles grid card, not a redesign.
/// M5's dashboard summary has no authorized member photos or favorites API.
/// Reuse the same card without inventing either of those protected properties.
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
    return Semantics(
      label: '${data.name}, ${data.memberCount == 1 ? '1 member' : '${data.memberCount} members'}, open Circle',
      button: true,
      child: CircleGroupCard(
        data: CircleGroupData(
          id: data.id,
          name: data.name,
          memberCount: data.memberCount,
          memberAvatars: const <String?>[],
        ),
        onTap: onTap,
        onFavoritePressed: null,
        // Identical to live My Circles: no favorite control without backend.
        showFavoriteButton: false,
      ),
    );
  }
}
