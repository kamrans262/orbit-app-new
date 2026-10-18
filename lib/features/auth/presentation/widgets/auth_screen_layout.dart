import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class AuthScreenLayout extends StatelessWidget {
  const AuthScreenLayout({required this.child, super.key});

  static const double horizontalMargin = 20;
  static const double verticalMargin = 20;
  static const double maxCardWidth = 560;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalInset = MediaQuery.sizeOf(context).width <= 340
                ? 16.0
                : horizontalMargin;
            final minimumCenteredHeight = math.max(
              0.0,
              constraints.maxHeight - (verticalMargin * 2) - keyboardInset,
            );

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                verticalMargin,
                horizontalInset,
                verticalMargin + keyboardInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumCenteredHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxCardWidth),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
