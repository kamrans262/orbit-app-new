import 'package:flutter/material.dart';

import '../../../../core/widgets/app_social_button.dart';

class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({
    required this.onApplePressed,
    required this.onGooglePressed,
    this.appleKey,
    this.googleKey,
    super.key,
  });

  final VoidCallback onApplePressed;
  final VoidCallback onGooglePressed;
  final Key? appleKey;
  final Key? googleKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically = constraints.maxWidth < 260;
        final apple = AppSocialButton(
          key: appleKey,
          label: 'Apple',
          icon: const Icon(Icons.apple, size: 22, color: Colors.black),
          onPressed: onApplePressed,
        );
        final google = AppSocialButton(
          key: googleKey,
          label: 'Google',
          icon: const GoogleGMark(size: 20),
          onPressed: onGooglePressed,
        );

        if (stackVertically) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[apple, const SizedBox(height: 10), google],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: apple),
            const SizedBox(width: 12),
            Expanded(child: google),
          ],
        );
      },
    );
  }
}
