import 'package:flutter/material.dart';

class CircleSettingToggle extends StatelessWidget {
  const CircleSettingToggle({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  static const double _trackWidth = 24;
  static const double _trackHeight = 14;
  static const double _thumbExtent = 10;

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 32,
          height: 28,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: _trackWidth,
              height: _trackHeight,
              padding: const EdgeInsets.all(2),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? null : const Color(0xFFD4D4D4),
                gradient: value
                    ? const LinearGradient(
                        colors: <Color>[Color(0xFFED65C9), Color(0xFF7C3AED)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(_trackHeight / 2),
              ),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: _thumbExtent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
