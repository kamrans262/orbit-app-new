import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

class OrbitDropdownField extends StatelessWidget {
  const OrbitDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.fieldKey,
    super.key,
  });

  static const double referenceHeight = 51;
  static const double radius = 30;
  static const double horizontalPadding = 16;

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final effectiveItems = <String>[
      if (value.isNotEmpty && !items.contains(value)) value,
      ...items,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F1724),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          key: fieldKey,
          width: double.infinity,
          height: referenceHeight,
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveItems.contains(value) ? value : null,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF94A3B8),
                size: 24,
              ),
              dropdownColor: Colors.white,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F1724),
              ),
              items: <DropdownMenuItem<String>>[
                for (final item in effectiveItems)
                  DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (next) {
                if (next != null && next != value) {
                  onChanged(next);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
