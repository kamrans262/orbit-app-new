import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/popups/orbit_popup_modal.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/models/circle_settings.dart';
import '../widgets/circle_color_selector.dart';
import '../widgets/circle_setting_toggle.dart';
import 'circle_invite_management_screen.dart';

abstract final class CircleSettingKeys {
  static const scrollView = Key('circle_setting_scroll_view');
  static const backButton = Key('circle_setting_back_button');
  static const title = Key('circle_setting_title');
  static const summaryName = Key('circle_setting_summary_name');
  static const memberCount = Key('circle_setting_member_count');
  static const nameLabel = Key('circle_setting_name_label');
  static const nameField = Key('circle_setting_name_field');
  static const colorLabel = Key('circle_setting_color_label');
  static const colorSelector = Key('circle_setting_color_selector');
  static const deleteButton = Key('circle_setting_delete_button');
  static const saveButton = Key('circle_setting_save_button');
  static const deleteConfirmButton = Key('circle_setting_delete_confirm');
  static const retryButton = Key('circle_setting_retry_button');
  static const inviteManagementEntry = Key(
    'circle_setting_invite_management_entry',
  );

  static Key row(String id) => Key('circle_setting_row_$id');
  static Key toggle(String id) => Key('circle_setting_toggle_$id');
}

class CircleSettingScreen extends StatefulWidget {
  const CircleSettingScreen({
    this.settings,
    this.viewState = CircleSettingsViewState.loaded,
    this.errorMessage = 'Unable to load circle settings.',
    this.availableColors = CircleColorSelector.defaultOptions,
    this.onBack,
    this.onRetry,
    this.onSettingsChanged,
    this.onDeleteConfirmed,
    this.onInviteManagementPressed,
    this.sharingControlsEnabled = true,
    this.sharingControlsReadOnly = false,
    this.archiveInsteadOfDelete = false,
    this.showDestructiveAction = true,
    this.onManagePressed,
    this.onSavePressed,
    this.saveEnabled = false,
    this.saving = false,
    super.key,
  }) : assert(
         viewState != CircleSettingsViewState.loaded || settings != null,
         'settings is required when viewState is loaded.',
       );

  factory CircleSettingScreen.demo({
    VoidCallback? onBack,
    ValueChanged<CircleSettings>? onSettingsChanged,
    ValueChanged<CircleSettings>? onDeleteConfirmed,
    VoidCallback? onInviteManagementPressed,
  }) {
    return CircleSettingScreen(
      settings: const CircleSettings(
        id: 'best-friends',
        name: 'Best Friends',
        memberCount: 5,
        colorValue: 0xFF4D6EF5,
        liveLocationEnabled: true,
        momentSharingEnabled: true,
        pingEnabled: false,
        sosAlertsEnabled: true,
      ),
      onBack: onBack,
      onSettingsChanged: onSettingsChanged,
      onDeleteConfirmed: onDeleteConfirmed,
      onInviteManagementPressed: onInviteManagementPressed,
    );
  }

  final CircleSettings? settings;
  final CircleSettingsViewState viewState;
  final String errorMessage;
  final List<CircleColorOption> availableColors;
  final VoidCallback? onBack;
  final VoidCallback? onRetry;
  final ValueChanged<CircleSettings>? onSettingsChanged;
  final ValueChanged<CircleSettings>? onDeleteConfirmed;
  final VoidCallback? onInviteManagementPressed;
  final bool sharingControlsEnabled;
  final bool sharingControlsReadOnly;
  final bool archiveInsteadOfDelete;
  final bool showDestructiveAction;
  final VoidCallback? onManagePressed;
  final VoidCallback? onSavePressed;
  final bool saveEnabled;
  final bool saving;

  @override
  State<CircleSettingScreen> createState() => _CircleSettingScreenState();
}

class _CircleSettingScreenState extends State<CircleSettingScreen> {
  static const double _horizontalPadding = 20;
  static const double _topPadding = 20;
  static const double _headerToSummaryGap = 16;
  static const double _summaryToFormGap = 26;
  static const double _nameToColorGap = 12;
  static const double _labelToColorGap = 8;
  static const double _colorToRowsGap = 14;
  static const double _rowGap = 10;
  static const double _rowsToDeleteGap = 68;
  static const double _deleteHeight = 54;
  static const double _maxContentWidth = 430;

  late final TextEditingController _nameController;
  CircleSettings? _settings;
  bool _syncingController = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _nameController = TextEditingController(text: widget.settings?.name ?? '');
  }

  @override
  void didUpdateWidget(covariant CircleSettingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.settings, widget.settings) &&
        widget.settings != null) {
      _settings = widget.settings;
      final nextName = widget.settings!.name;
      if (_nameController.text != nextName) {
        _syncingController = true;
        _nameController.value = TextEditingValue(
          text: nextName,
          selection: TextSelection.collapsed(offset: nextName.length),
        );
        _syncingController = false;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: widget.onSavePressed == null ? null : SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    KeyedSubtree(
                      key: CircleSettingKeys.saveButton,
                      child: AppPrimaryButton(
                        label: widget.saving ? 'Saving…' : 'Save Changes',
                        enabled: widget.saveEnabled && !widget.saving,
                        onPressed: widget.onSavePressed!,
                      ),
                    ),
                    if (widget.showDestructiveAction) ...<Widget>[
                      const SizedBox(height: 12),
                      _DeleteCircleButton(
                        onTap: widget.saving ? () {} : _showDeleteConfirmation,
                        label: widget.archiveInsteadOfDelete
                            ? 'Archive Circle' : 'Delete Circle',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return IgnorePointer(
                ignoring: widget.saving,
                child: SingleChildScrollView(
                key: CircleSettingKeys.scrollView,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  _topPadding,
                  _horizontalPadding,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildHeader(context),
                        const SizedBox(height: _headerToSummaryGap),
                        if (widget.viewState == CircleSettingsViewState.loaded)
                          _buildLoadedContent()
                        else if (widget.viewState ==
                            CircleSettingsViewState.loading)
                          const _CircleSettingsLoadingState()
                        else
                          _CircleSettingsErrorState(
                            message: widget.errorMessage,
                            onRetry: widget.onRetry,
                          ),
                      ],
                    ),
                  ),
                ),
              ));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: AppScreenHeader(
            title: 'Setting',
            onBack: widget.onBack,
            backButtonKey: CircleSettingKeys.backButton,
            titleKey: CircleSettingKeys.title,
          ),
        ),
        if (widget.onManagePressed != null)
          AppCircularIconButton(
            semanticLabel: 'Manage Circle',
            onPressed: widget.onManagePressed!,
            icon: Icons.more_horiz_rounded,
            iconSize: 24,
            iconColor: AppColors.primaryEnd,
            iconGradient: AppColors.primaryGradient,
          ),
      ],
    );
  }

  Widget _buildLoadedContent() {
    final settings = _settings!;
    final trimmedName = settings.name.trim();
    final displayName = trimmedName.isEmpty ? 'Circle' : trimmedName;
    final memberLabel = settings.memberCount == 1
        ? '1 member'
        : '${settings.memberCount} members';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CircleSummary(
          name: displayName,
          memberLabel: memberLabel,
          onTap: _openInviteManagement,
        ),
        const SizedBox(height: _summaryToFormGap),
        AppTextField(
          label: 'Circle Name',
          labelKey: CircleSettingKeys.nameLabel,
          fieldKey: CircleSettingKeys.nameField,
          controller: _nameController,
          textInputAction: TextInputAction.done,
          onChanged: _handleNameChanged,
        ),
        const SizedBox(height: _nameToColorGap),
        const Text(
          'Color',
          key: CircleSettingKeys.colorLabel,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F1724),
          ),
        ),
        const SizedBox(height: _labelToColorGap),
        KeyedSubtree(
          key: CircleSettingKeys.colorSelector,
          child: CircleColorSelector(
            selectedValue: settings.colorValue,
            options: widget.availableColors,
            onSelected: _handleColorSelected,
          ),
        ),
        const SizedBox(height: _colorToRowsGap),
        if (widget.sharingControlsEnabled || widget.sharingControlsReadOnly) ...<Widget>[
        _buildSettingRow(
          id: 'live_location',
          title: 'Live Location',
          icon: Icons.location_on_outlined,
          iconColor: const Color(0xFF5D7FF4),
          iconBackground: const Color(0xFFE3E9FD),
          value: settings.liveLocationEnabled,
          onChanged: (value) =>
              _updateSettings(settings.copyWith(liveLocationEnabled: value)),
        ),
        const SizedBox(height: _rowGap),
        _buildSettingRow(
          id: 'moment_sharing',
          title: 'Moment Sharing',
          icon: Icons.photo_camera_outlined,
          iconColor: const Color(0xFF5ACDAE),
          iconBackground: const Color(0xFFE4F7F2),
          value: settings.momentSharingEnabled,
          onChanged: (value) =>
              _updateSettings(settings.copyWith(momentSharingEnabled: value)),
        ),
        const SizedBox(height: _rowGap),
        _buildSettingRow(
          id: 'ping',
          title: 'Ping',
          icon: Icons.bolt_rounded,
          iconColor: const Color(0xFF7C3AED),
          iconBackground: const Color(0xFFF2EAFE),
          value: settings.pingEnabled,
          onChanged: (value) =>
              _updateSettings(settings.copyWith(pingEnabled: value)),
        ),
        const SizedBox(height: _rowGap),
        _buildSettingRow(
          id: 'sos_alerts',
          title: 'SOS Alerts',
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFF43F8E),
          iconBackground: const Color(0xFFFFDCEB),
          value: settings.sosAlertsEnabled,
          onChanged: (value) =>
              _updateSettings(settings.copyWith(sosAlertsEnabled: value)),
        ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Location, Moments, Ping and SOS sharing are OFF. '
              'Circle membership never enables sharing automatically.',
              style: TextStyle(fontFamily: AppTypography.fontFamily,
                fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
        if (widget.onSavePressed == null && widget.showDestructiveAction) ...<Widget>[
          const SizedBox(height: _rowsToDeleteGap),
          _DeleteCircleButton(
            onTap: _showDeleteConfirmation,
            label: widget.archiveInsteadOfDelete ? 'Archive Circle' : 'Delete Circle'),
        ],
      ],
    );
  }

  Widget _buildSettingRow({
    required String id,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AppActionRow(
      containerKey: CircleSettingKeys.row(id),
      leadingIcon: icon,
      iconBackgroundColor: iconBackground,
      leadingIconColor: iconColor,
      title: title,
      trailing: CircleSettingToggle(
        key: CircleSettingKeys.toggle(id),
        value: value,
        semanticLabel: '$title ${value ? 'enabled' : 'disabled'}',
        enabled: widget.sharingControlsEnabled,
        onChanged: onChanged,
      ),
    );
  }

  void _handleNameChanged(String value) {
    if (_syncingController || _settings == null) {
      return;
    }
    _updateSettings(_settings!.copyWith(name: value));
  }

  void _handleColorSelected(CircleColorOption option) {
    if (_settings == null || _settings!.colorValue == option.value) {
      return;
    }
    _updateSettings(_settings!.copyWith(colorValue: option.value));
  }

  void _updateSettings(CircleSettings next) {
    if (!mounted) {
      return;
    }
    setState(() => _settings = next);
    widget.onSettingsChanged?.call(next);
  }

  void _openInviteManagement() {
    final callback = widget.onInviteManagementPressed;
    if (callback != null) {
      callback();
      return;
    }

    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => CircleInviteManagementScreen.demo(),
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final settings = _settings;
    if (settings == null) {
      return;
    }

    final confirmed = await showOrbitPopupModal<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => OrbitPopupModal(
        title: widget.archiveInsteadOfDelete ? 'Archive Circle?' : 'Delete Circle?',
        description: widget.archiveInsteadOfDelete
            ? 'The Circle will be hidden and pending invitations revoked. You can restore it later.'
            : 'This action requires confirmation before the circle can be deleted.',
        primaryAction: KeyedSubtree(
          key: CircleSettingKeys.deleteConfirmButton,
          child: OrbitPopupDestructiveButton(
            label: widget.archiveInsteadOfDelete ? 'Archive' : 'Delete',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
        secondaryAction: OrbitPopupTextButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      widget.onDeleteConfirmed?.call(settings);
    }
  }
}

class _CircleSummary extends StatelessWidget {
  const _CircleSummary({
    required this.name,
    required this.memberLabel,
    required this.onTap,
  });

  final String name;
  final String memberLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open circle invite management',
      child: GestureDetector(
        key: CircleSettingKeys.inviteManagementEntry,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              name,
              key: CircleSettingKeys.summaryName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F1724),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              memberLabel,
              key: CircleSettingKeys.memberCount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 10,
                height: 1.3,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteCircleButton extends StatelessWidget {
  const _DeleteCircleButton({required this.onTap, this.label = 'Delete Circle'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: CircleSettingKeys.deleteButton,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: _CircleSettingScreenState._deleteHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0x1ADC3232),
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: Color(0xFFF44336),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF44336),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleSettingsLoadingState extends StatelessWidget {
  const _CircleSettingsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }
}

class _CircleSettingsErrorState extends StatelessWidget {
  const _CircleSettingsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w400,
              color: Color(0xFF64748B),
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 16),
            TextButton(
              key: CircleSettingKeys.retryButton,
              onPressed: onRetry,
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
