import 'package:flutter/material.dart';

class AppCircularIconButton extends StatelessWidget {
  const AppCircularIconButton({
    required this.onPressed,
    required this.icon,
    this.size = 30,
    this.iconSize = 20,
    this.iconColor = Colors.black,
    this.iconGradient,
    this.backgroundColor = Colors.white,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final double size;
  final double iconSize;
  final Color iconColor;
  final Gradient? iconGradient;
  final Color backgroundColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, size: iconSize, color: iconColor);
    if (iconGradient != null) {
      iconWidget = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => iconGradient!.createShader(bounds),
        child: Icon(icon, size: iconSize, color: Colors.white),
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Material(
          color: backgroundColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: size,
              child: Center(child: iconWidget),
            ),
          ),
        ),
      ),
    );
  }
}
