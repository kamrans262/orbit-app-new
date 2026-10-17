import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/friend_details_models.dart';

abstract final class CircleGroupSegmentedControlKeys {
  static const circle = Key('friend_details_segment_circle');
  static const group = Key('friend_details_segment_group');
}

class CircleGroupSegmentedControl extends StatelessWidget {
  const CircleGroupSegmentedControl({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final FriendDetailsSegment value;
  final ValueChanged<FriendDetailsSegment> onChanged;

  static const LinearGradient _selectedGradient = LinearGradient(
    colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _SegmentButton(
                key: CircleGroupSegmentedControlKeys.circle,
                label: 'Circle',
                selected: value == FriendDetailsSegment.circle,
                onTap: () => onChanged(FriendDetailsSegment.circle),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _SegmentButton(
                key: CircleGroupSegmentedControlKeys.group,
                label: 'Group',
                selected: value == FriendDetailsSegment.group,
                onTap: () => onChanged(FriendDetailsSegment.group),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected
                  ? CircleGroupSegmentedControl._selectedGradient
                  : null,
              color: selected ? null : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF94A3B8),
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}
