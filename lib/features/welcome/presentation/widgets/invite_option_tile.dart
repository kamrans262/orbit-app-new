import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_row.dart';

class InviteOptionTile extends StatelessWidget {
  const InviteOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.containerKey,
    super.key,
  });

  static const Color iconColor = Color(0xFF7C3AED);
  static const Color iconBackground = Color(0xFFF2EAFE);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Key? containerKey;

  @override
  Widget build(BuildContext context) {
    return AppActionRow(
      containerKey: containerKey,
      leadingIcon: icon,
      iconBackgroundColor: iconBackground,
      leadingIconColor: iconColor,
      title: label,
      onTap: onTap,
    );
  }
}
