import 'package:flutter/material.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../circles/presentation/widgets/circle_setting_toggle.dart';
import '../../domain/models/privacy_settings.dart';
import '../widgets/orbit_dropdown_field.dart';
import 'blocked_users_screen.dart';

abstract final class PrivacySettingKeys {
  static const scrollView = Key('privacy_setting_scroll_view');
  static const backButton = Key('privacy_setting_back_button');
  static const title = Key('privacy_setting_title');
  static const locationVisibility = Key('privacy_location_visibility');
  static const locationActivity = Key('privacy_location_activity');
  static const locationSharingRow = Key('privacy_location_sharing_row');
  static const locationSharingToggle = Key('privacy_location_sharing_toggle');
  static const ghostModeRow = Key('privacy_ghost_mode_row');
  static const ghostModeToggle = Key('privacy_ghost_mode_toggle');
  static const blockUserRow = Key('privacy_block_user_row');
}

class PrivacySettingScreen extends StatefulWidget {
  const PrivacySettingScreen({
    this.initialSettings = PrivacySettings.demo,
    this.locationVisibilityOptions = const <String>[
      'My Circle',
      'Friends',
      'Selected People',
      'Nobody',
    ],
    this.locationActivityOptions = const <String>[
      'abcfg..',
      'Active',
      'While moving',
      'Off',
    ],
    this.onSettingsChanged,
    this.onBlockedUsersPressed,
    this.onBack,
    super.key,
  });

  final PrivacySettings initialSettings;
  final List<String> locationVisibilityOptions;
  final List<String> locationActivityOptions;
  final ValueChanged<PrivacySettings>? onSettingsChanged;
  final VoidCallback? onBlockedUsersPressed;
  final VoidCallback? onBack;

  @override
  State<PrivacySettingScreen> createState() => _PrivacySettingScreenState();
}

class _PrivacySettingScreenState extends State<PrivacySettingScreen> {
  static const double _screenPadding = 20;
  static const double _headerToBodyGap = 24;
  static const double _betweenDropdownSections = 18;
  static const double _dropdownsToRowsGap = 16;
  static const double _rowGap = 12;
  static const double _maxContentWidth = 600;

  late PrivacySettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  void didUpdateWidget(covariant PrivacySettingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSettings != widget.initialSettings) {
      _settings = widget.initialSettings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _screenPadding,
                  _screenPadding,
                  _screenPadding,
                  0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: AppScreenHeader(
                      title: 'Privacy Setting',
                      onBack: widget.onBack,
                      backButtonKey: PrivacySettingKeys.backButton,
                      titleKey: PrivacySettingKeys.title,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _headerToBodyGap),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: ListView(
                      key: PrivacySettingKeys.scrollView,
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(
                        _screenPadding,
                        0,
                        _screenPadding,
                        _screenPadding,
                      ),
                      children: <Widget>[
                        OrbitDropdownField(
                          fieldKey: PrivacySettingKeys.locationVisibility,
                          label: 'Who can see location',
                          value: _settings.locationVisibility,
                          items: widget.locationVisibilityOptions,
                          onChanged: (value) => _update(
                            _settings.copyWith(locationVisibility: value),
                          ),
                        ),
                        const SizedBox(height: _betweenDropdownSections),
                        OrbitDropdownField(
                          fieldKey: PrivacySettingKeys.locationActivity,
                          label: 'Location Activity',
                          value: _settings.locationActivity,
                          items: widget.locationActivityOptions,
                          onChanged: (value) => _update(
                            _settings.copyWith(locationActivity: value),
                          ),
                        ),
                        const SizedBox(height: _dropdownsToRowsGap),
                        _PrivacyToggleRow(
                          rowKey: PrivacySettingKeys.locationSharingRow,
                          toggleKey: PrivacySettingKeys.locationSharingToggle,
                          title: 'Location Sharing',
                          value: _settings.locationSharingEnabled,
                          onChanged: (value) => _update(
                            _settings.copyWith(locationSharingEnabled: value),
                          ),
                        ),
                        const SizedBox(height: _rowGap),
                        _PrivacyToggleRow(
                          rowKey: PrivacySettingKeys.ghostModeRow,
                          toggleKey: PrivacySettingKeys.ghostModeToggle,
                          title: 'Ghost mode',
                          value: _settings.ghostModeEnabled,
                          onChanged: (value) => _update(
                            _settings.copyWith(ghostModeEnabled: value),
                          ),
                        ),
                        const SizedBox(height: _rowGap),
                        _PrivacyNavigationRow(
                          rowKey: PrivacySettingKeys.blockUserRow,
                          title: 'Block User',
                          onTap: _openBlockedUsers,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _update(PrivacySettings next) {
    if (!mounted || next == _settings) {
      return;
    }
    setState(() => _settings = next);
    widget.onSettingsChanged?.call(next);
  }

  void _openBlockedUsers() {
    final override = widget.onBlockedUsersPressed;
    if (override != null) {
      override();
      return;
    }

    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(builder: (_) => const BlockedUsersScreen()),
    );
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  const _PrivacyToggleRow({
    required this.rowKey,
    required this.toggleKey,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Key rowKey;
  final Key toggleKey;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: AppActionRow(
        containerKey: rowKey,
        leadingIcon: Icons.circle,
        iconBackgroundColor: Colors.transparent,
        leadingIconColor: Colors.transparent,
        showLeading: false,
        title: title,
        onTap: () => onChanged(!value),
        trailing: IgnorePointer(
          child: CircleSettingToggle(
            key: toggleKey,
            value: value,
            semanticLabel: '$title ${value ? 'enabled' : 'disabled'}',
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _PrivacyNavigationRow extends StatelessWidget {
  const _PrivacyNavigationRow({
    required this.rowKey,
    required this.title,
    required this.onTap,
  });

  final Key rowKey;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: AppActionRow(
        containerKey: rowKey,
        leadingIcon: Icons.circle,
        iconBackgroundColor: Colors.transparent,
        leadingIconColor: Colors.transparent,
        showLeading: false,
        title: title,
        onTap: onTap,
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
          size: 24,
        ),
      ),
    );
  }
}
