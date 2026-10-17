import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import 'welcome_layout_metrics.dart';

class WelcomeActionPanel extends StatelessWidget {
  const WelcomeActionPanel({
    required this.primaryKey,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryKey,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.reserveSecondarySlot = false,
    super.key,
  });

  final Key primaryKey;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final Key? secondaryKey;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool reserveSecondarySlot;

  @override
  Widget build(BuildContext context) {
    final secondaryHeight = AppSecondaryButton.heightFor(context);
    final hasSecondary = secondaryLabel != null && onSecondaryPressed != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: WelcomeLayoutMetrics.maxButtonWidth,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            key: primaryKey,
            child: AppPrimaryButton(
              label: primaryLabel,
              onPressed: onPrimaryPressed,
            ),
          ),
          if (hasSecondary || reserveSecondarySlot) ...<Widget>[
            const SizedBox(height: WelcomeLayoutMetrics.buttonGap),
            if (hasSecondary)
              SizedBox(
                key: secondaryKey,
                child: AppSecondaryButton(
                  label: secondaryLabel!,
                  onPressed: onSecondaryPressed!,
                ),
              )
            else
              SizedBox(height: secondaryHeight),
          ],
        ],
      ),
    );
  }
}
