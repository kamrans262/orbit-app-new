import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';

/// Existing Friends Details selection style, shared without visual changes.
class AppTwoOptionSegmentedControl extends StatelessWidget {
  const AppTwoOptionSegmentedControl({required this.firstLabel,
    required this.secondLabel,required this.firstSelected,
    required this.onChanged,this.firstKey,this.secondKey,super.key});
  final String firstLabel,secondLabel;
  final bool firstSelected;
  final ValueChanged<bool> onChanged;
  final Key? firstKey,secondKey;

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
                key: firstKey,
                label: firstLabel,
                selected: firstSelected,
                onTap: () => onChanged(true),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _SegmentButton(
                key: secondKey,
                label: secondLabel,
                selected: !firstSelected,
                onTap: () => onChanged(false),
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
                  ? AppTwoOptionSegmentedControl._selectedGradient
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
