import 'package:flutter/material.dart';

import '../../../more_menu/presentation/widgets/more_menu_tile.dart';
import '../../domain/models/home_models.dart';
import 'home_media_image.dart';

/// Real M5 Circle preview using the approved Orbit Menu row, rather
/// than the My Circles grid or Home's circular friend avatars.
/// The M5 API has no per-Circle image or persistent favorite field yet.
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
    return MoreMenuTile(
      icon: Icons.groups_outlined,
      iconColor: const Color(0xFF7C3AED),
      iconBackgroundColor: const Color(0xFFF2EAFE),
      title: data.name,
      subtitle: memberLabel,
      onTap: onTap,
      // Original Orbit artwork is only a placeholder, never an invented
      // member photo or an unauthorized encrypted user image.
      leadingWidget: ClipOval(
        child: HomeMediaImage(
          path: 'assets/your_circle.png',
          fit: BoxFit.cover,
          fallback: HomeAvatar(imagePath: '', name: data.name, size: 42),
        ),
      ),
      // Original Orbit heart. Decorative and unselected until favorites
      // are actually supported by the server — no fake persistent toggle.
      trailingWidget: const Semantics(
        label: 'Circle favorites unavailable',
        child: Icon(
          Icons.favorite_border_rounded,
          size: 20,
          color: Color(0xFFFF4757),
        ),
      ),
    );
  }
}
