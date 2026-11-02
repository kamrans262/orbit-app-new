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
    this.onSaveSettings,
    this.onBack,
    this.systemPermissionFooter,
    this.additionalSettings=const <NotificationSupplementalSetting>[],
    super.key,
  });

  final NotificationSettings initialSettings;
  final ValueChanged<NotificationSettings>? onSettingsChanged;
  final Future<NotificationSettings> Function(NotificationSettings)? onSaveSettings;
  final VoidCallback? onBack;
  /// Appends status without modifying the seven approved setting toggles.
  final Widget? systemPermissionFooter;
  /// Reuses approved toggle row and key/spacing without altering M3 fields.
  final List<NotificationSupplementalSetting> additionalSettings;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const double _screenPadding = 20;
  static const double _headerToRowsGap = 20;
  static const double _rowGap = 12;
  static const double _maxContentWidth = 600;

  late NotificationSettings _settings;
  bool _saving = false;

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
        title: 'SOS & Safety alerts',
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

    rows.addAll(widget.additionalSettings.map((setting)=>_NotificationRowSpec(
      id:setting.id,title:setting.title,value:setting.value,
      onChanged:setting.onChanged,
    )));
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
                      itemCount: rows.length + (widget.systemPermissionFooter==null?0:1),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: _rowGap),
                      itemBuilder: (context, index) {
                        if(index==rows.length)return widget.systemPermissionFooter!;
                        final row = rows[index];
                        if (row.id == 'sos') {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text('Safety alerts are managed separately from social alerts. Device permissions may still affect delivery.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF5D6574))),
                              const SizedBox(height: 8),
                              _NotificationSettingRow(spec: row),
                            ],
                          );
                        }
                        return _NotificationSettingRow(spec: row);
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

  Future<void> _update(NotificationSettings next) async {
    if (!mounted || _saving || next == _settings) return;
    final save = widget.onSaveSettings;
    if (save == null) {
      setState(() => _settings = next);
      widget.onSettingsChanged?.call(next);
      return;
    }
    setState(() => _saving = true);
    try {
      final confirmed = await save(next);
      if (!mounted) return;
      setState(() => _settings = confirmed);
      widget.onSettingsChanged?.call(confirmed);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notification preference could not be saved. The previous value is still active.'),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

/// Additive category toggle rendered exactly like the existing M3 rows.
class NotificationSupplementalSetting {
  const NotificationSupplementalSetting({
    required this.id,required this.title,required this.value,
    required this.onChanged,
  });
  final String id,title;
  final bool value;
  final ValueChanged<bool> onChanged;
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
