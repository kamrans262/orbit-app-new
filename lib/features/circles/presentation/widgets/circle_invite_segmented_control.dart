import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/circle_invite.dart';

class CircleInviteSegmentedControl extends StatelessWidget {
  const CircleInviteSegmentedControl({
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const double height = 56;
  static const double radius = 30;
  static const Duration animationDuration = Duration(milliseconds: 260);

  final CircleInviteTab value;
  final ValueChanged<CircleInviteTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = value.index;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth =
              constraints.maxWidth / CircleInviteTab.values.length;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F1F6),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AnimatedPositioned(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  left: segmentWidth * selectedIndex + 4,
                  top: 4,
                  bottom: 4,
                  width: segmentWidth - 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[AppColors.primaryStart, AppColors.primaryEnd],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x16000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: CircleInviteTab.values
                      .map((tab) {
                        final selected = tab == value;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label: '${_label(tab)} invites',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onChanged(tab),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: animationDuration,
                                  curve: Curves.easeOutCubic,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 16,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF303030),
                                  ),
                                  child: Text(
                                    _label(tab),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _label(CircleInviteTab tab) {
    switch (tab) {
      case CircleInviteTab.sent:
        return 'Sent';
      case CircleInviteTab.pending:
        return 'Pending';
      case CircleInviteTab.accepted:
        return 'Accepted';
    }
  }
}
