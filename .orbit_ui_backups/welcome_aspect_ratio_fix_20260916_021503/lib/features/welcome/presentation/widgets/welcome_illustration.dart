import 'package:flutter/material.dart';

class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key});

  static const imageKey = Key('welcome_illustration');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Friends and family staying connected with Orbit',
      child: SizedBox.expand(
        key: imageKey,
        child: ClipRect(
          child: Image.asset(
            'assets/welcome.png',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
