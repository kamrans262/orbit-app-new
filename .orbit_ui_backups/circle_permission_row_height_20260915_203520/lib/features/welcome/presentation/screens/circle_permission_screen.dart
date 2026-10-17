import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class CirclePermissionKeys {
  static const backButton = Key('circle_permission_back_button');
  static const title = Key('circle_permission_title');
  static const createCircleButton = Key('circle_permission_create_button');

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
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onCreateCircle;

  @override
  State<CirclePermissionScreen> createState() => _CirclePermissionScreenState();
}

class _CirclePermissionScreenState extends State<CirclePermissionScreen> {
  static const double _topGap = 20;
  static const double _topBarGap = 10;
  static const double _topBarToRowsGap = 20;
  static const double _rowHeight = 68;
  static const double _rowGap = 10;
  static const double _screenHorizontalPadding = 20;

  final List<bool> _permissions = <bool>[true, true, false, true, true];

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

  void _togglePermission(int index) {
    setState(() => _permissions[index] = !_permissions[index]);
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
                              _PermissionRow(
                                index: index,
                                item: _items[index],
                                value: _permissions[index],
                                onChanged: () => _togglePermission(index),
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
                      primaryLabel: 'Create Circle',
                      onPrimaryPressed: widget.onCreateCircle,
                      reserveSecondarySlot: true,
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

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.index,
    required this.item,
    required this.value,
    required this.onChanged,
  });

  final int index;
  final _PermissionItemData item;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: CirclePermissionKeys.row(index),
      height: _CirclePermissionScreenState._rowHeight,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Container(
            key: CirclePermissionKeys.iconCircle(index),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.iconBackground,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, size: 22, color: item.iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F1724),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _PermissionToggle(index: index, value: value, onTap: onChanged),
        ],
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.index,
    required this.value,
    required this.onTap,
  });

  final int index;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      label: value ? 'Permission enabled' : 'Permission disabled',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: CirclePermissionKeys.toggle(index),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: AnimatedContainer(
                key: CirclePermissionKeys.toggleTrack(index),
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                width: 24,
                height: 14,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: value
                      ? const Color(0xFF9A48EA)
                      : const Color(0xFFD4D4D4),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: 10),
                ),
              ),
            ),
          ),
        ),
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
