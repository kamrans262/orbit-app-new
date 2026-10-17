import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/ping_models.dart';

class PingOptionCard extends StatefulWidget {
  const PingOptionCard({
    required this.option,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final PingOption option;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<PingOptionCard> createState() => _PingOptionCardState();
}

class _PingOptionCardState extends State<PingOptionCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.option.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        onTapUp: widget.enabled
            ? (_) {
                _setPressed(false);
                widget.onTap();
              }
            : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          scale: _pressed ? 0.992 : 1,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 110),
            opacity: widget.enabled ? (_pressed ? 0.90 : 1) : 0.55,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: widget.option.backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 32,
                    child: Center(
                      child: Text(
                        widget.option.emoji,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Noto Color Emoji',
                          fontFamilyFallback: <String>[
                            'Segoe UI Emoji',
                            'Apple Color Emoji',
                            'sans-serif',
                          ],
                          fontSize: 25,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      widget.option.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: widget.option.foregroundColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
