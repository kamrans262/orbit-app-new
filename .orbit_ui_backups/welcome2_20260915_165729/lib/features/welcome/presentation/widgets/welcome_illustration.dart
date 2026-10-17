import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Friends and family staying connected with Orbit',
      child: SizedBox(
        key: const Key('welcome_illustration'),
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 1.24,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Positioned.fill(
                top: 22,
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/welcome.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              const Positioned(
                left: 28,
                top: 44,
                child: _ConnectorLine(angle: -0.72),
              ),
              const Positioned(left: 2, top: 8, child: _LocationBadge()),
              const Positioned(
                right: 62,
                top: 0,
                child: _ConnectorLine(angle: 0.32),
              ),
              const Positioned(right: 48, top: 0, child: _ProfileBadge()),
              const Positioned(right: 0, top: 58, child: _AddBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  const _LocationBadge();

  @override
  Widget build(BuildContext context) {
    return const _BadgeShell(
      size: 46,
      child: Icon(
        Icons.location_on_rounded,
        color: Color(0xFFA64DF4),
        size: 27,
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge();

  @override
  Widget build(BuildContext context) {
    return _BadgeShell(
      size: 46,
      padding: 4,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.avatarGreen,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.person_rounded, color: AppColors.white, size: 29),
        ),
      ),
    );
  }
}

class _AddBadge extends StatelessWidget {
  const _AddBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryStart, width: 1.4),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.add_rounded,
        color: AppColors.primaryStart,
        size: 28,
      ),
    );
  }
}

class _BadgeShell extends StatelessWidget {
  const _BadgeShell({
    required this.size,
    required this.child,
    this.padding = 0,
  });

  final double size;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine({required this.angle});

  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      alignment: Alignment.topCenter,
      child: Container(width: 1.4, height: 38, color: AppColors.connectorLine),
    );
  }
}
