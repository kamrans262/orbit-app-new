import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../profile/presentation/widgets/orbit_person_action_tile.dart';
import '../../domain/models/circle_invite.dart';
import '../widgets/invite_status_badge.dart';

class CircleInviteDetailScreen extends StatelessWidget {
  const CircleInviteDetailScreen({
    required this.invite,
    this.onBack,
    super.key,
  });

  final CircleInvite invite;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppScreenHeader(title: 'Invite details', onBack: onBack),
                  const SizedBox(height: 20),
                  OrbitPersonActionTile(
                    name: invite.userName,
                    avatarSource: invite.avatarUrl,
                    trailing: InviteStatusBadge(status: invite.status),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Circle invitation',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F1724),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Invite created ${_dateLabel(invite.createdAt)}',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _dateLabel(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
