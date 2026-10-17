import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import 'app_primary_button.dart';

class AppSocialButton extends StatelessWidget {
  const AppSocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  static const double radius = 30;
  static const Color borderColor = Color(0x1A000000);

  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppPrimaryButton.heightFor(context),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox.square(dimension: 22, child: Center(child: icon)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: const <String>[
                        'Noto Color Emoji',
                        'Apple Color Emoji',
                        'Segoe UI Emoji',
                      ],
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F1724),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleGMark extends StatelessWidget {
  const GoogleGMark({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleGMarkPainter()),
    );
  }
}

class _GoogleGMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.2;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    void arc(Color color, double startDegrees, double sweepDegrees) {
      paint.color = color;
      canvas.drawArc(
        rect,
        startDegrees * math.pi / 180,
        sweepDegrees * math.pi / 180,
        false,
        paint,
      );
    }

    arc(const Color(0xFF4285F4), -45, 95);
    arc(const Color(0xFFEA4335), 50, 90);
    arc(const Color(0xFFFBBC05), 140, 65);
    arc(const Color(0xFF34A853), 205, 110);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final centerY = size.height * 0.52;
    canvas.drawRect(
      Rect.fromLTRB(
        size.width * 0.5,
        centerY - stroke / 2,
        size.width * 0.94,
        centerY + stroke / 2,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGMarkPainter oldDelegate) => false;
}
