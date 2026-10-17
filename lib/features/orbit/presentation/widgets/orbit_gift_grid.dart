import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/orbit_models.dart';

class OrbitGiftGrid extends StatelessWidget {
  const OrbitGiftGrid({required this.items, required this.onTap, super.key});

  final List<OrbitGiftData> items;
  final ValueChanged<OrbitGiftData> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'No gifts available.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: const <String>[
                'Noto Color Emoji',
                'Apple Color Emoji',
                'Segoe UI Emoji',
              ],
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Semantics(
          button: true,
          label: item.label ?? item.id,
          child: InkResponse(
            onTap: () => onTap(item),
            radius: 36,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final emojiSize = (constraints.maxWidth * 0.62).clamp(
                  28.0,
                  48.0,
                );
                return Center(
                  child: Text(
                    item.emoji,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: emojiSize, height: 1),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
