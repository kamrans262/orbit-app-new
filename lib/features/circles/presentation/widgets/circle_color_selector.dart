import 'package:flutter/material.dart';

class CircleColorOption {
  const CircleColorOption({required this.label, required this.value});

  final String label;
  final int value;

  Color get color => Color(value);
}

class CircleColorSelector extends StatelessWidget {
  const CircleColorSelector({
    required this.selectedValue,
    required this.onSelected,
    this.options = defaultOptions,
    super.key,
  });

  static const List<CircleColorOption> defaultOptions = <CircleColorOption>[
    CircleColorOption(label: 'Blue', value: 0xFF4D6EF5),
    CircleColorOption(label: 'Coral', value: 0xFFFF4666),
    CircleColorOption(label: 'Orange', value: 0xFFFF9F0A),
    CircleColorOption(label: 'Green', value: 0xFF3ACF93),
    CircleColorOption(label: 'Purple', value: 0xFFA24BEA),
    CircleColorOption(label: 'Cyan', value: 0xFF12AFC7),
    CircleColorOption(label: 'Pink', value: 0xFFF43F8E),
  ];

  static const double _containerHeight = 58;
  static const double _horizontalPadding = 16;
  static const double _tapExtent = 34;
  static const double _swatchExtent = 30;
  static const double _overflowGap = 10;

  final int selectedValue;
  final List<CircleColorOption> options;
  final ValueChanged<CircleColorOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _containerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (options.isEmpty) {
            return const SizedBox.expand();
          }

          final requiredWidth =
              (options.length * _tapExtent) +
              ((options.length - 1) * _overflowGap);

          if (requiredWidth <= constraints.maxWidth) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (final option in options) _buildOption(option),
              ],
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: <Widget>[
                for (
                  var index = 0;
                  index < options.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) const SizedBox(width: _overflowGap),
                  _buildOption(options[index]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOption(CircleColorOption option) {
    final selected = selectedValue == option.value;

    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} circle color',
      child: GestureDetector(
        key: ValueKey<String>(
          'circle_setting_color_${option.label.toLowerCase()}',
        ),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(option),
        child: SizedBox.square(
          dimension: _tapExtent,
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              scale: selected ? 1 : 0.93,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                width: _swatchExtent,
                height: _swatchExtent,
                decoration: BoxDecoration(
                  color: option.color,
                  shape: BoxShape.circle,
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: option.color.withAlpha(54),
                            blurRadius: 7,
                            spreadRadius: 1,
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
