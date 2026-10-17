import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

class OrbitMessageActionRow extends StatelessWidget {
  const OrbitMessageActionRow({
    required this.personName,
    required this.controller,
    required this.onCameraPressed,
    required this.onSendPressed,
    super.key,
  });

  final String personName;
  final TextEditingController controller;
  final VoidCallback onCameraPressed;
  final VoidCallback onSendPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFF),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: controller,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF0F1724),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Message $personName',
                hintStyle: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF94A3B8),
                ),
                contentPadding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _OrbitRoundActionButton(
          semanticLabel: 'Camera',
          onPressed: onCameraPressed,
          backgroundColor: const Color(0xFFF3F3F7),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: <Color>[Color(0xFFED65C9), Color(0xFF7C3AED)],
            ).createShader(bounds),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 21,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _OrbitRoundActionButton(
          semanticLabel: 'Send message',
          onPressed: onSendPressed,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
          ),
          child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
        ),
      ],
    );
  }
}

class _OrbitRoundActionButton extends StatelessWidget {
  const _OrbitRoundActionButton({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.gradient,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          gradient: gradient,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(dimension: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}
