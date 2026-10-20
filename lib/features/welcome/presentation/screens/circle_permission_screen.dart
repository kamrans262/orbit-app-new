import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class CirclePermissionKeys {
  static const backButton = Key('circle_permission_back_button');
  static const title = Key('circle_permission_title');
  static const createCircleButton = Key('circle_permission_create_button');
  static const skipButton = Key('circle_permission_skip_button');

  static Key row(int index) => Key('circle_permission_row_$index');
  static Key iconCircle(int index) => Key('circle_permission_icon_$index');
  static Key toggle(int index) => Key('circle_permission_toggle_$index');
  static Key toggleTrack(int index) =>
      Key('circle_permission_toggle_track_$index');
}

class CirclePermissionScreen extends StatefulWidget {
  const CirclePermissionScreen({
    required this.onBack,
    required this.onCreateCircle,
    this.onSkip,
    this.circleAlreadyCreated = false,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onCreateCircle;
  final VoidCallback? onSkip;
  final bool circleAlreadyCreated;

  @override
  State<CirclePermissionScreen> createState() => _CirclePermissionScreenState();
}

class _CirclePermissionScreenState extends State<CirclePermissionScreen> {
  static const double _topGap = 20;
  static const double _topBarGap = 10;
  static const double _topBarToRowsGap = 20;
  static const double _rowGap = 10;
  static const double _screenHorizontalPadding = 20;

  final List<bool> _permissions = <bool>[false, false, false, false, false];

  static const List<_PermissionItemData> _items = <_PermissionItemData>[
    _PermissionItemData(
      label: 'Live Location',
      icon: Icons.location_on_outlined,
      iconColor: Color(0xFF5D7FF4),
      iconBackground: Color(0xFFE3E9FD),
    ),
    _PermissionItemData(
      label: 'Moment Sharing',
      icon: Icons.photo_camera_outlined,
      iconColor: Color(0xFF5ACDAE),
      iconBackground: Color(0xFFE4F7F2),
    ),
    _PermissionItemData(
      label: 'Ping',
      icon: Icons.bolt_rounded,
      iconColor: Color(0xFF7C3AED),
      iconBackground: Color(0xFFF2EAFE),
    ),
    _PermissionItemData(
      label: 'SOS Alerts',
      icon: Icons.error_outline_rounded,
      iconColor: Color(0xFFF43F8E),
      iconBackground: Color(0xFFFFDCEB),
    ),
    _PermissionItemData(
      label: 'Emoji & Gifting',
      icon: Icons.sentiment_satisfied_alt_rounded,
      iconColor: Color(0xFF16B88B),
      iconBackground: Color(0xFFE2F8F2),
    ),
  ];

  void _setPermission(int index, bool value) {
    // Backend M5 has no approved location/media/messaging grants. Do not
    // represent a local toggle as saved privacy consent.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Sharing stays OFF until the secure sharing feature is available.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final buttonHorizontalPadding =
                WelcomeLayoutMetrics.horizontalPadding(constraints.maxWidth);
            final contentBottomInset = WelcomeLayoutMetrics.contentBottomInset(
              context,
            );

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  bottom: contentBottomInset,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      _screenHorizontalPadding,
                      _topGap,
                      _screenHorizontalPadding,
                      16,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: WelcomeLayoutMetrics.maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _CirclePermissionTopBar(onBack: widget.onBack),
                            const SizedBox(height: _topBarToRowsGap),
                            for (
                              var index = 0;
                              index < _items.length;
                              index++
                            ) ...<Widget>[
                              AppActionRow(
                                containerKey: CirclePermissionKeys.row(index),
                                iconCircleKey: CirclePermissionKeys.iconCircle(
                                  index,
                                ),
                                toggleKey: CirclePermissionKeys.toggle(index),
                                toggleTrackKey:
                                    CirclePermissionKeys.toggleTrack(index),
                                leadingIcon: _items[index].icon,
                                iconBackgroundColor:
                                    _items[index].iconBackground,
                                leadingIconColor: _items[index].iconColor,
                                title: _items[index].label,
                                toggleValue: _permissions[index],
                                onToggleChanged: (value) =>
                                    _setPermission(index, value),
                              ),
                              if (index < _items.length - 1)
                                const SizedBox(height: _rowGap),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: buttonHorizontalPadding,
                  right: buttonHorizontalPadding,
                  bottom: WelcomeLayoutMetrics.bottomSpacing,
                  child: Center(
                    child: WelcomeActionPanel(
                      primaryKey: CirclePermissionKeys.createCircleButton,
                      primaryLabel: widget.circleAlreadyCreated ? 'Continue to Invites' : 'Create Circle',
                      onPrimaryPressed: widget.onCreateCircle,
                      secondaryKey: widget.onSkip == null
                          ? null
                          : CirclePermissionKeys.skipButton,
                      secondaryLabel: widget.onSkip == null ? null : 'Skip',
                      onSecondaryPressed: widget.onSkip,
                      reserveSecondarySlot: widget.onSkip == null,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CirclePermissionTopBar extends StatelessWidget {
  const _CirclePermissionTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0A000000),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: CirclePermissionKeys.backButton,
                onTap: onBack,
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 24,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _CirclePermissionScreenState._topBarGap),
          const Expanded(
            child: Text(
              'Circle Permission',
              key: CirclePermissionKeys.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionItemData {
  const _PermissionItemData({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
}
