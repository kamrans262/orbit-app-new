import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';

abstract final class WelcomeLayoutMetrics {
  static const double buttonGap = 10;
  static const double bottomSpacing = 20;
  static const double maxContentWidth = 560;
  static const double maxButtonWidth = 560;

  static double horizontalPadding(double width) => width < 360 ? 18 : 24;

  static double actionPanelHeight(BuildContext context) {
    final buttonHeight = AppPrimaryButton.heightFor(context);
    return (buttonHeight * 2) + buttonGap;
  }

  static double contentBottomInset(BuildContext context) {
    return actionPanelHeight(context) + bottomSpacing;
  }

  // Kept for compatibility with any existing code that still references it.
  static double actionAreaHeight(BuildContext context) {
    return contentBottomInset(context);
  }
}
