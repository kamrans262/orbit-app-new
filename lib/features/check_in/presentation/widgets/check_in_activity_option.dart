import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/check_in_models.dart';

class CheckInActivityOption extends StatelessWidget {
  const CheckInActivityOption({
    required this.data,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CheckInActivityData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: selected ? 1.04 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.isMore
                      ? Colors.black
                      : selected
                      ? Color.alphaBlend(
                          const Color(0x1A7C3AED),
                          data.backgroundColor,
                        )
                      : data.backgroundColor,
                  border: selected && !data.isMore
                      ? Border.all(color: const Color(0x667C3AED), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: data.isMore
                      ? const Text(
                          '•••',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 16,
                            height: 1,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(9),
                          child: SvgPicture.asset(
                            data.iconAsset,
                            fit: BoxFit.contain,
                            colorFilter: ColorFilter.mode(
                              data.iconColor,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
