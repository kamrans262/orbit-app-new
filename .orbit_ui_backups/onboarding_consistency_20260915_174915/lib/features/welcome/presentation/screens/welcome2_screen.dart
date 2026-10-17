import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';

abstract final class Welcome2Keys {
  static const map = Key('welcome2_map');
  static const nextButton = Key('welcome2_next_button');
}

class Welcome2Screen extends StatelessWidget {
  const Welcome2Screen({required this.onNext, super.key});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final horizontalPadding = constraints.maxWidth < 360 ? 18.0 : 24.0;
            final mapHeight = (constraints.maxWidth * 1.06)
                .clamp(compact ? 360.0 : 410.0, 620.0)
                .toDouble();

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        compact ? AppSpacing.xl : 52,
                        horizontalPadding,
                        compact ? AppSpacing.lg : AppSpacing.xxl,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            children: <Widget>[
                              const Text(
                                'Live. Share. Protect',
                                textAlign: TextAlign.center,
                                style: AppTypography.largeHeading,
                              ),
                              SizedBox(height: compact ? 16 : AppSpacing.xl),
                              const Text(
                                "See where your people are in\nreal-time and know they're\nsafe.",
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : AppSpacing.md),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SizedBox(
                          height: mapHeight,
                          width: double.infinity,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: <Widget>[
                              Positioned.fill(
                                child: Semantics(
                                  image: true,
                                  label: 'Orbit live location map',
                                  child: Image.asset(
                                    'assets/map.png',
                                    key: Welcome2Keys.map,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    filterQuality: FilterQuality.high,
                                    gaplessPlayback: true,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                left: horizontalPadding,
                                right: horizontalPadding,
                                bottom: compact ? AppSpacing.md : 22,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 620,
                                    ),
                                    child: SizedBox(
                                      key: Welcome2Keys.nextButton,
                                      child: AppPrimaryButton(
                                        label: 'Next',
                                        onPressed: onNext,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
