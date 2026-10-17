import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../circles/presentation/widgets/circle_setting_toggle.dart';
import '../../domain/models/notification_settings.dart';

abstract final class NotificationKeys {
  static const scrollView = Key('notification_scroll_view');
  static const backButton = Key('notification_back_button');
  static const title = Key('notification_title');

  static Key row(String id) => Key('notification_row_$id');
  static Key toggle(String id) => Key('notification_toggle_$id');
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    this.initialSettings = NotificationSettings.demo,
    this.onSettingsChanged,
    this.onBack,
    super.key,
  });

  final NotificationSettings initialSettings;
  final ValueChanged<NotificationSettings>? onSettingsChanged;
  final VoidCallback? onBack;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const double _screenPadding = 20;
  static const double _headerToRowsGap = 20;
  static const double _rowGap = 12;
  static const double _maxContentWidth = 600;

  late NotificationSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  void didUpdateWidget(covariant NotificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSettings != widget.initialSettings) {
      _settings = widget.initialSettings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_NotificationRowSpec>[
      _NotificationRowSpec(
        id: 'push',
        title: 'Push Notification',
        value: _settings.pushNotificationsEnabled,
        onChanged: (value) =>
            _update(_settings.copyWith(pushNotificationsEnabled: value)),
      ),
      _NotificationRowSpec(
        id: 'ping',
        title: 'Ping notifications',
        value: _settings.pingNotificationsEnabled,
        onChanged: (value) =>
            _update(_settings.copyWith(pingNotificationsEnabled: value)),
      ),
      _NotificationRowSpec(
        id: 'moments',
        title: 'Moments notifications',
        value: _settings.momentsNotificationsEnabled,
        onChanged: (value) =>
            _update(_settings.copyWith(momentsNotificationsEnabled: value)),
      ),
      _NotificationRowSpec(
        id: 'circle_updates',
        title: 'Circle updates',
        value: _settings.circleUpdatesEnabled,
        onChanged: (value) =>
            _update(_settings.copyWith(circleUpdatesEnabled: value)),
      ),
      _NotificationRowSpec(
        id: 'sos',
        title: 'SOS alerts',
        value: _settings.sosAlertsEnabled,
        onChanged: (value) =>
            _update(_settings.copyWith(sosAlertsEnabled: value)),
      ),
      _NotificationRowSpec(
        id: 'sound',
        title: 'Sound',
        value: _settings.soundEnabled,
        onChanged: (value) => _update(_settings.copyWith(soundEnabled: value)),
      ),
      _NotificationRowSpec(
        id: 'vibration',
        title: 'Vibration',
        value: _settings.vibrationEnabled,
        onChanged: (value) =>
            _update(_settings.copyWith(vibrationEnabled: value)),
      ),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
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
                      title: 'Notification',
                      onBack: widget.onBack,
                      backButtonKey: NotificationKeys.backButton,
                      titleKey: NotificationKeys.title,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _headerToRowsGap),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: ListView.separated(
                      key: NotificationKeys.scrollView,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        _screenPadding,
                        0,
                        _screenPadding,
                        _screenPadding,
                      ),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: _rowGap),
                      itemBuilder: (context, index) {
                        return _NotificationSettingRow(spec: rows[index]);
                      },
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

  void _update(NotificationSettings next) {
    if (!mounted || next == _settings) {
      return;
    }
    setState(() => _settings = next);
    widget.onSettingsChanged?.call(next);
  }
}

class _NotificationSettingRow extends StatelessWidget {
  const _NotificationSettingRow({required this.spec});

  final _NotificationRowSpec spec;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: spec.value,
      label: spec.title,
      onTap: () => spec.onChanged(!spec.value),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: AppActionRow(
          containerKey: NotificationKeys.row(spec.id),
          leadingIcon: Icons.circle,
          iconBackgroundColor: Colors.transparent,
          leadingIconColor: Colors.transparent,
          showLeading: false,
          title: spec.title,
          onTap: () => spec.onChanged(!spec.value),
          trailing: IgnorePointer(
            child: CircleSettingToggle(
              key: NotificationKeys.toggle(spec.id),
              value: spec.value,
              semanticLabel:
                  '${spec.title} ${spec.value ? 'enabled' : 'disabled'}',
              onChanged: spec.onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRowSpec {
  const _NotificationRowSpec({
    required this.id,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String id;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
}
