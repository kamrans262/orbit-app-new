import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/popups/orbit_popup_modal.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'package:flutter/services.dart';

/// Public identifiers for Orbit Devices widget/navigation tests.
abstract final class DevicesKeys {
  static const title = Key('devices_title');
  static const back = Key('devices_back');
  static const scrollView = Key('devices_scroll_view');
  static const status = Key('devices_status');
  static const register = Key('devices_register');
  static const retry = Key('devices_retry');
  static const renameField = Key('devices_rename_field');

  static Key row(String id) => ValueKey<String>('devices_row_$id');
  static Key rename(String id) => ValueKey<String>('devices_rename_$id');
  static Key revoke(String id) => ValueKey<String>('devices_revoke_$id');
  static Key approve(String id) => ValueKey<String>('devices_approve_$id');
}

/// A presentation-only device model. Backend IDs and trusted status must come
/// from the authenticated account's server response, not local demo data.
@immutable
class OrbitRegisteredDevice {
  const OrbitRegisteredDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastSeenLabel,
    this.isCurrent = false,
    this.isTrusted = false,
    this.isApprovalPending = false,
  });

  final String id;
  final String name;
  final String platform;
  final String lastSeenLabel;
  final bool isCurrent;
  final bool isTrusted;
  final bool isApprovalPending;
}

/// Settings -> Devices. [devices] == null explicitly means that a live device
/// list is not connected yet. The screen never invents signed-in devices,
/// changes trust state locally, or reports a successful revocation without a
/// backend callback.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({
    this.devices,
    this.onLoadDevices,
    this.onRenameDevice,
    this.onRevokeDevice,
    this.onApproveDevice,
    this.onRegisterDevicePressed,
    this.onBack,
    super.key,
  });

  final List<OrbitRegisteredDevice>? devices;
  final Future<List<OrbitRegisteredDevice>> Function()? onLoadDevices;
  final Future<void> Function(String deviceId, String newName)? onRenameDevice;
  final Future<void> Function(String deviceId)? onRevokeDevice;
  final Future<void> Function(String deviceId)? onApproveDevice;
  final VoidCallback? onRegisterDevicePressed;
  final VoidCallback? onBack;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  static const double _margin = 20;
  List<OrbitRegisteredDevice>? _devices;
  bool _loading = false;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _devices = widget.devices;
    if (widget.onLoadDevices != null) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant DevicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.devices != oldWidget.devices) {
      _devices = widget.devices;
    }
    if (widget.onLoadDevices != oldWidget.onLoadDevices &&
        widget.onLoadDevices != null) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final loader = widget.onLoadDevices;
    if (loader == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await loader();
      if (mounted) setState(() => _devices = next);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your devices. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _rename(OrbitRegisteredDevice device) async {
    if (_busyId != null) return;
    final rename = widget.onRenameDevice;
    if (rename == null) {
      _message('Renaming will be available after your account is connected.');
      return;
    }
    final controller = TextEditingController(text: device.name);
    String? newName;
    try {
      newName = await showOrbitPopupModal<String>(
        context: context,
        popupId: 'rename_device',
        builder: (dialogContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(dialogContext).bottom,
          ),
          child: OrbitPopupModal(
            title: 'Rename device',
            showCloseButton: true,
            onClose: () => Navigator.of(dialogContext).pop(),
            content: AppTextField(
              label: 'Device name',
              fieldKey: DevicesKeys.renameField,
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(48),
              ],
            ),
            primaryAction: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final name = value.text.trim();
                return OrbitPopupPrimaryButton(
                  label: 'Save',
                  enabled: name.isNotEmpty &&
                      name.length <= 48 &&
                      name != device.name,
                  onPressed: () => Navigator.of(dialogContext).pop(name),
                );
              },
            ),
            secondaryAction: OrbitPopupTextButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
    if (!mounted || newName == null || newName == device.name) return;
    await _runAction(
      device.id,
      () => rename(device.id, newName!),
      'Could not rename this device. Please retry.',
    );
  }

  Future<void> _revoke(OrbitRegisteredDevice device) async {
    if (_busyId != null || device.isCurrent) return;
    final revoke = widget.onRevokeDevice;
    if (revoke == null) {
      _message(
        'Device removal will be available after your account is connected.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Remove device?',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Remove ${device.name} from your Orbit account? '
          'Its session and message access must be revoked by the server.',
          style: AppTypography.body,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _runAction(
      device.id,
      () => revoke(device.id),
      'Could not remove this device. Please retry.',
    );
  }

  Future<void> _approve(OrbitRegisteredDevice device) async {
    if (_busyId != null || !device.isApprovalPending) return;
    final approve = widget.onApproveDevice;
    if (approve == null) {
      _message(
        'Device approval will be available after your account is connected.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Trust this device?',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Approve ${device.name} only if you recognize this device.',
          style: AppTypography.body,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _runAction(
      device.id,
      () => approve(device.id),
      'Could not approve this device. Please retry.',
    );
  }

  Future<void> _runAction(
    String deviceId,
    Future<void> Function() action,
    String failureMessage,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = deviceId);
    try {
      await action();
      if (!mounted) return;
      if (widget.onLoadDevices != null) {
        await _load();
      } else {
        _message(
          'Request completed. Refresh device data to see account changes.',
        );
      }
    } catch (_) {
      _message(failureMessage);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(_margin, 20, _margin, 0),
                  child: AppScreenHeader(
                    title: 'Devices',
                    titleKey: DevicesKeys.title,
                    backButtonKey: DevicesKeys.back,
                    onBack: widget.onBack,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    key: DevicesKeys.scrollView,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(_margin, 0, _margin, 20),
                    children: <Widget>[
                      Text(
                        'Your trusted devices',
                        style: AppTypography.smallHeading,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage devices that can access your private Orbit conversations.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_loading && devices == null)
                        _InformationCard(
                          key: DevicesKeys.status,
                          icon: Icons.sync_rounded,
                          title: 'Loading devices…',
                          message: 'Checking your registered devices.',
                        )
                      else if (_error != null)
                        _InformationCard(
                          key: DevicesKeys.status,
                          icon: Icons.error_outline_rounded,
                          title: 'Could not load devices',
                          message: _error!,
                        )
                      else if (devices == null)
                        const _InformationCard(
                          key: DevicesKeys.status,
                          icon: Icons.devices_other_rounded,
                          title: 'Account connection pending',
                          message: 'Your registered devices will appear here when the account backend is connected.',
                        )
                      else if (devices.isEmpty)
                        const _InformationCard(
                          key: DevicesKeys.status,
                          icon: Icons.devices_other_rounded,
                          title: 'No registered devices',
                          message: 'Your account has no registered devices to display.',
                        )
                      else ...<Widget>[
                        for (final device in devices) ...<Widget>[
                          _DeviceCard(
                            key: DevicesKeys.row(device.id),
                            device: device,
                            busy: _busyId != null,
                            onRename: () => unawaited(_rename(device)),
                            onRevoke: () => unawaited(_revoke(device)),
                            onApprove: () => unawaited(_approve(device)),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                      if (_error != null &&
                          widget.onLoadDevices != null) ...<Widget>[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: DevicesKeys.retry,
                          onPressed: _loading ? null : () => unawaited(_load()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                      if (_loading && devices != null) ...<Widget>[
                        const SizedBox(height: 12),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'A new device must be verified before it can access encrypted messages. Never approve a device you do not recognize.',
                        style: AppTypography.body.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (widget.onRegisterDevicePressed != null) ...<Widget>[
                        const SizedBox(height: 20),
                        AppPrimaryButton(
                          key: DevicesKeys.register,
                          label: 'Register a device',
                          onPressed: widget.onRegisterDevicePressed!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 27, color: AppColors.primaryEnd),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.busy,
    required this.onRename,
    required this.onRevoke,
    required this.onApprove,
    super.key,
  });

  final OrbitRegisteredDevice device;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onRevoke;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      device.platform,
      device.lastSeenLabel,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox.square(
                dimension: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x1FA576F6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_android_rounded,
                    size: 24,
                    color: AppColors.primaryEnd,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _DevicePill(
                label: device.isCurrent
                    ? 'This device'
                    : device.isApprovalPending
                    ? 'Pending approval'
                    : device.isTrusted
                    ? 'Trusted'
                    : 'Registered',
              ),
              TextButton.icon(
                key: DevicesKeys.rename(device.id),
                onPressed: busy ? null : onRename,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Rename'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryEnd,
                ),
              ),
              if (device.isApprovalPending && !device.isCurrent)
                TextButton.icon(
                  key: DevicesKeys.approve(device.id),
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.verified_outlined, size: 17),
                  label: const Text('Approve'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryEnd,
                  ),
                ),
              if (!device.isCurrent)
                TextButton.icon(
                  key: DevicesKeys.revoke(device.id),
                  onPressed: busy ? null : onRevoke,
                  icon: const Icon(Icons.phonelink_erase_outlined, size: 17),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFAD3149),
                  ),
                ),
            ],
          ),
          if (device.isCurrent) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              'To end this device’s session, use Log Out in Orbit Menu.',
              style: AppTypography.body.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DevicePill extends StatelessWidget {
  const _DevicePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x1FA576F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryEnd,
          ),
        ),
      ),
    );
  }
}
