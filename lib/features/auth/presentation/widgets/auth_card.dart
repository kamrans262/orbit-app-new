import 'dart:ui';

import 'package:flutter/material.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({required this.child, this.cardKey, super.key});

  static const double radius = 30;
  static const double topPadding = 36;
  static const double horizontalPadding = 24;
  static const double bottomPadding = 28;
  static const double blurSigma = 20;
  static const Color borderColor = Color(0x14FFFFFF);

  final Widget child;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          key: cardKey,
          padding: const EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}
