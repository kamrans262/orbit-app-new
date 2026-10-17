import 'package:flutter/material.dart';

import '../../domain/models/check_in_models.dart';
import 'check_in_activity_option.dart';

class CheckInActivitySelector extends StatelessWidget {
  const CheckInActivitySelector({
    required this.activities,
    required this.selectedId,
    required this.onSelected,
    this.onMorePressed,
    super.key,
  });

  final List<CheckInActivityData> activities;
  final String? selectedId;
  final ValueChanged<CheckInActivityData> onSelected;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context) {
    final rows = <List<CheckInActivityData>>[];
    for (var i = 0; i < activities.length; i += 5) {
      rows.add(
        activities.sublist(i, (i + 5).clamp(0, activities.length).toInt()),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x26000000), blurRadius: 2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (
              var rowIndex = 0;
              rowIndex < rows.length;
              rowIndex++
            ) ...<Widget>[
              _ActivityRow(
                activities: rows[rowIndex],
                selectedId: selectedId,
                onSelected: (activity) {
                  if (activity.isMore) {
                    onMorePressed?.call();
                    return;
                  }
                  onSelected(activity);
                },
              ),
              if (rowIndex != rows.length - 1) ...const <Widget>[
                SizedBox(height: 16),
                Divider(height: 1, thickness: 1, color: Color(0x14000000)),
                SizedBox(height: 16),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activities,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CheckInActivityData> activities;
  final String? selectedId;
  final ValueChanged<CheckInActivityData> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(5, (index) {
        if (index >= activities.length) {
          return const Expanded(child: SizedBox.shrink());
        }
        final activity = activities[index];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: CheckInActivityOption(
              data: activity,
              selected: selectedId == activity.id,
              onTap: () => onSelected(activity),
            ),
          ),
        );
      }),
    );
  }
}
