import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_action_row.dart';

/// Full-width Orbit Circle sheet. Reuses the app's white rounded container,
/// pill action rows, spacing and palette instead of native popup menus.
Future<T?> showOrbitCircleSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F1724),
                  ),
                ),
                const SizedBox(height: 18),
                builder(sheet),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A consistent white Orbit pill action with a colored circular icon.
class OrbitCircleSheetAction extends StatelessWidget {
  const OrbitCircleSheetAction({
    required this.title,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => AppActionRow(
    leadingIcon: icon,
    iconBackgroundColor: destructive
        ? const Color(0xFFFFE5E5) : const Color(0xFFF2EAFE),
    leadingIconColor: destructive
        ? const Color(0xFFF44336) : AppColors.primaryEnd,
    title: title,
    trailing: const Icon(Icons.chevron_right_rounded,
        size: 22, color: Color(0xFF94A3B8)),
    onTap: onTap,
  );
}
