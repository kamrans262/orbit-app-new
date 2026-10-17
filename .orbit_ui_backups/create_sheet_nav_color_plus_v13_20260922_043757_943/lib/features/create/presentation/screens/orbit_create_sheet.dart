import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../moments/presentation/orbit_moment_camera_launcher.dart';
import '../../../ping/presentation/screens/ping_screen.dart';
import '../../../sos/presentation/screens/sos_alert_screen.dart';
import 'orbit_write_post_screen.dart';

abstract final class OrbitCreateKeys {
  static const sheet = Key('orbit_create_sheet');
  static const panel = Key('orbit_create_panel');
  static const close = Key('orbit_create_close');
  static const postMoment = Key('orbit_create_post_moment');
  static const writePost = Key('orbit_create_write_post');
  static const ping = Key('orbit_create_ping');
  static const sos = Key('orbit_create_sos');
}

enum _CreateAction { moment, post, ping, sos }

/// The shared bottom-navigation + has ONE entry point, registered in main.dart.
/// The selected destination opens only after THIS sheet route has fully closed.
abstract final class OrbitCreateSheet {
  static bool _opening = false;

  static void open(BuildContext context) {
    unawaited(_open(context));
  }

  static Future<void> _open(BuildContext context) async {
    if (_opening || !context.mounted) return;
    _opening = true;
    final navigator = Navigator.of(context);
    final route = PageRouteBuilder<_CreateAction>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 230),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (routeContext, animation, secondaryAnimation) =>
          const _CreateSheetRouteBody(),
      transitionsBuilder: (routeContext, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curve, child: child);
      },
    );

    _CreateAction? selected;
    try {
      selected = await navigator.push<_CreateAction>(route);
      // Navigator.push completes at pop initiation; TransitionRoute.completed
      // completes only after its reverse transition and overlay are removed.
      await route.completed;
    } finally {
      _opening = false;
    }
    if (selected == null || !context.mounted || !navigator.mounted) return;

    switch (selected) {
      case _CreateAction.moment:
        // Reuse the existing remembered-permission and single-init camera flow.
        OrbitMomentCameraLauncher.open(context);
        return;
      case _CreateAction.post:
        await navigator.push<void>(
          AppFadeSlidePageRoute<void>(
            builder: (_) => const OrbitWritePostScreen(),
          ),
        );
        return;
      case _CreateAction.ping:
        await navigator.push<void>(
          AppFadeSlidePageRoute<void>(builder: (_) => PingScreen.demo()),
        );
        return;
      case _CreateAction.sos:
        await navigator.push<void>(
          AppFadeSlidePageRoute<void>(builder: (_) => SosAlertScreen.demo()),
        );
        return;
    }
  }
}

class _CreateSheetRouteBody extends StatefulWidget {
  const _CreateSheetRouteBody();

  @override
  State<_CreateSheetRouteBody> createState() => _CreateSheetRouteBodyState();
}

class _CreateSheetRouteBodyState extends State<_CreateSheetRouteBody> {
  bool _closing = false;

  void _select(_CreateAction? action) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop<_CreateAction>(action);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Keep the shared bottom navigation visible while Create is open.
    final bottomDock =
        AppBottomNavigationBar.referenceHeight + media.padding.bottom;
    final availableHeight =
        (media.size.height - media.padding.top - bottomDock - 10)
            .clamp(120.0, media.size.height)
            .toDouble();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            bottom: bottomDock,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _select(null),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            bottom: bottomDock,
            left: 0,
            right: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: availableHeight),
              child: DecoratedBox(
                key: OrbitCreateKeys.panel,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x19000000),
                      offset: Offset(0, -4),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: SingleChildScrollView(
                    key: OrbitCreateKeys.sheet,
                    physics: const ClampingScrollPhysics(),
                    // Extra breathing room after the last action row while
                    // the fixed bottom navigation remains visible below the sheet.
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        // Preserve the reference's two-column action grid.
                        // Each card ALWAYS uses icon -> text -> chevron in one row.
                        const gap = 10.0;
                        final compact = (width - gap) / 2 < 165;
                        final actions = <_CreateOption>[
                          _CreateOption(
                            key: OrbitCreateKeys.postMoment,
                            label: 'Post a Moment',
                            description: 'Share a photo or video memory',
                            icon: Icons.image_rounded,
                            iconColor: AppColors.primaryEnd,
                            circleColor: const Color(0xFFF0E8FF),
                            onTap: () => _select(_CreateAction.moment),
                          ),
                          _CreateOption(
                            key: OrbitCreateKeys.writePost,
                            label: 'Write a Post',
                            description: 'Share an update or a thought',
                            icon: Icons.article_rounded,
                            iconColor: const Color(0xFF3976E8),
                            circleColor: const Color(0xFFE8F0FF),
                            onTap: () => _select(_CreateAction.post),
                          ),
                          _CreateOption(
                            key: OrbitCreateKeys.ping,
                            label: 'Ping',
                            description: 'Check in or alert friends',
                            icon: Icons.location_on_rounded,
                            iconColor: const Color(0xFF169B62),
                            circleColor: const Color(0xFFDFF9EF),
                            onTap: () => _select(_CreateAction.ping),
                          ),
                          _CreateOption(
                            key: OrbitCreateKeys.sos,
                            label: 'Emergency / SOS',
                            description: 'Get help from your circle',
                            icon: Icons.health_and_safety_rounded,
                            iconColor: const Color(0xFFE72E70),
                            circleColor: const Color(0xFFFFE8EF),
                            onTap: () => _select(_CreateAction.sos),
                          ),
                        ];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Center(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragEnd: (details) {
                                  if ((details.primaryVelocity ?? 0) > 350) {
                                    _select(null);
                                  }
                                },
                                child: SizedBox(
                                  width: 72,
                                  height: 16,
                                  child: Center(
                                    child: Container(
                                      width: 44,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC6C3D9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: AppCircularIconButton(
                                key: OrbitCreateKeys.close,
                                semanticLabel: 'Close Create',
                                onPressed: () => _select(null),
                                icon: Icons.close_rounded,
                                size: 36,
                                iconSize: 19,
                                iconColor: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Create',
                              style: AppTypography.largeHeading.copyWith(
                                fontSize: 30,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Share something with your circle',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Natural card height keeps the vertical inset equal
                            // to the horizontal inset without forcing empty space.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: _CreateActionCard(
                                    option: actions[0],
                                    compact: compact,
                                  ),
                                ),
                                const SizedBox(width: gap),
                                Expanded(
                                  child: _CreateActionCard(
                                    option: actions[1],
                                    compact: compact,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: gap),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: _CreateActionCard(
                                    option: actions[2],
                                    compact: compact,
                                  ),
                                ),
                                const SizedBox(width: gap),
                                Expanded(
                                  child: _CreateActionCard(
                                    option: actions[3],
                                    compact: compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateOption {
  const _CreateOption({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.circleColor,
    required this.onTap,
  });

  final Key key;
  final String label;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color circleColor;
  final VoidCallback onTap;
}

class _CreateActionCard extends StatelessWidget {
  const _CreateActionCard({required this.option, required this.compact});

  final _CreateOption option;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Keep full action titles readable when the two-column grid becomes
    // narrow. The icon always stays exactly 48 x 48 logical pixels.
    final title = Text(
      option.label,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body.copyWith(
        fontSize: compact ? 10.5 : 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
    );
    final description = Text(
      option.description,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body.copyWith(
        fontSize: compact ? 9 : 10.5,
        height: 1.25,
        color: AppColors.textMuted,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDECF2), width: 1),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: option.key,
          onTap: option.onTap,
          child: Padding(
            // Match the 10px horizontal and vertical inset for all four cards.
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                Container(
                  key: Key('orbit_create_icon_${option.label}'),
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: option.circleColor,
                  ),
                  child: Icon(option.icon, color: option.iconColor, size: 24),
                ),
                SizedBox(width: compact ? 5 : 7),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      title,
                      const SizedBox(height: 3),
                      description,
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: compact ? 14 : 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
