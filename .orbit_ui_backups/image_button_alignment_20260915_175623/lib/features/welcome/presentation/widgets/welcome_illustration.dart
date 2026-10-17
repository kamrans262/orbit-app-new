import 'package:flutter/material.dart';

class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key});

  static const imageKey = Key('welcome_illustration');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Friends and family staying connected with Orbit',
      child: SizedBox(
        key: imageKey,
        width: double.infinity,
        child: Image.asset(
          'assets/welcome.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
