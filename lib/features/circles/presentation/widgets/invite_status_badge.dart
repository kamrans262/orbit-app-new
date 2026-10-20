import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/circle_invite.dart';

class InviteStatusBadge extends StatelessWidget {
  const InviteStatusBadge({required this.status, super.key});

  final CircleInviteStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(status);
    return Container(
      constraints: const BoxConstraints(minHeight: 35),
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 340 ? 10 : 18,
        vertical: 9,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        palette.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 15,
          height: 1,
          fontWeight: FontWeight.w500,
          color: palette.foreground,
        ),
      ),
    );
  }

  _InviteStatusPalette _paletteFor(CircleInviteStatus value) {
    switch (value) {
      case CircleInviteStatus.pending:
        return const _InviteStatusPalette(
          label: 'Pending',
          foreground: Color(0xFF7C3AED),
          background: Color(0xFFF2EAFE),
        );
      case CircleInviteStatus.accepted:
        return const _InviteStatusPalette(
          label: 'Accepted',
          foreground: Color(0xFF5ACDAE),
          background: Color(0xFFDFF7F1),
        );
      case CircleInviteStatus.declined:
        return const _InviteStatusPalette(
          label: 'Declined',
          foreground: Color(0xFFF44336),
          background: Color(0xFFFBE0E0),
        );
    }
  }
}

class _InviteStatusPalette {
  const _InviteStatusPalette({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}
