import 'dart:async';

import 'package:flutter/material.dart';

import 'orbit_popup_illustration.dart';
import 'orbit_popup_modal.dart';

typedef OrbitPopupCallback = FutureOr<void> Function();

enum OrbitPopupType {
  sos,
  liveLocation,
  logout,
  deleteAccount,
  stayConnected,
  cameraPermission,
  momentError,
  loading,
  batteryOptimization,
  microphonePermission,
}

enum OrbitPopupActionStyle { gradient, secondary, destructive, text }

abstract final class OrbitPopupVariantKeys {
  static Key popup(OrbitPopupType type) => Key('orbit_popup_${type.name}');
  static Key primary(OrbitPopupType type) =>
      Key('orbit_popup_primary_${type.name}');
  static Key secondary(OrbitPopupType type) =>
      Key('orbit_popup_secondary_${type.name}');
  static Key close(OrbitPopupType type) =>
      Key('orbit_popup_close_${type.name}');
}

Future<void> showSosPopup(
  BuildContext context, {
  required OrbitPopupCallback onTrustedContact,
  required OrbitPopupCallback onTrustedUser,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.sos,
    title: 'SOS',
    assetPath: 'assets/popup/sos.svg',
    motion: OrbitPopupIllustrationMotion.pulse,
    illustrationBackground: const Color(0xFFFFD0E3),
    illustrationBackgroundSize: 86,
    illustrationSvgSize: 56,
    primaryLabel: 'Trusted Contact',
    onPrimary: onTrustedContact,
    secondaryLabel: 'Trusted user',
    onSecondary: onTrustedUser,
    secondaryStyle: OrbitPopupActionStyle.secondary,
  );
}

Future<void> showLiveLocationPopup(
  BuildContext context, {
  required OrbitPopupCallback onGhost,
  required OrbitPopupCallback onLiveLocation,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.liveLocation,
    title: 'Live Location',
    assetPath: 'assets/popup/location.svg',
    motion: OrbitPopupIllustrationMotion.locationPulse,
    illustrationBackground: const Color(0xFFDCE6FF),
    illustrationBackgroundSize: 86,
    illustrationSvgSize: 48,
    primaryLabel: 'Ghost',
    onPrimary: onGhost,
    secondaryLabel: 'Live Location',
    onSecondary: onLiveLocation,
    secondaryStyle: OrbitPopupActionStyle.secondary,
  );
}

Future<void> showLogoutPopup(
  BuildContext context, {
  required OrbitPopupCallback onLogout,
  OrbitPopupCallback? onCancel,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.logout,
    title: 'Log Out',
    description: 'Are you sure you want to logout Of Orbit',
    assetPath: 'assets/popup/logout.svg',
    motion: OrbitPopupIllustrationMotion.slideRight,
    illustrationSvgSize: 82,
    primaryLabel: 'Log Out',
    onPrimary: onLogout,
    secondaryLabel: 'Cancel',
    onSecondary: onCancel,
    secondaryStyle: OrbitPopupActionStyle.text,
  );
}

Future<void> showDeleteAccountPopup(
  BuildContext context, {
  required OrbitPopupCallback onDelete,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.deleteAccount,
    title: 'Delete Account',
    description: 'This action cannot be undone. All your data will be permanently deleted.',
    assetPath: 'assets/popup/delete.svg',
    motion: OrbitPopupIllustrationMotion.scaleIn,
    illustrationSvgSize: 82,
    primaryLabel: 'Delete',
    onPrimary: onDelete,
    primaryStyle: OrbitPopupActionStyle.destructive,
  );
}

Future<void> showStayConnectedPopup(
  BuildContext context, {
  required OrbitPopupCallback onAllow,
  OrbitPopupCallback? onNotNow,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.stayConnected,
    title: 'Stay Connected In the Background',
    description:
        'Allow background location in loop you and you’re circle stay updated',
    assetPath: 'assets/popup/stay_connected.svg',
    motion: OrbitPopupIllustrationMotion.breathe,
    illustrationSvgSize: 86,
    primaryLabel: 'Allow',
    onPrimary: onAllow,
    secondaryLabel: 'Not Now',
    onSecondary: onNotNow,
    secondaryStyle: OrbitPopupActionStyle.text,
  );
}

Future<void> showCameraPermissionPopup(
  BuildContext context, {
  required OrbitPopupCallback onAllow,
  OrbitPopupCallback? onNotNow,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.cameraPermission,
    title: 'Allow Camera Access',
    description: 'Orbit needs camera access to capture moments',
    assetPath: 'assets/popup/camera.svg',
    motion: OrbitPopupIllustrationMotion.cameraPulse,
    illustrationSvgSize: 86,
    primaryLabel: 'Allow',
    onPrimary: onAllow,
    secondaryLabel: 'Not Now',
    onSecondary: onNotNow,
    secondaryStyle: OrbitPopupActionStyle.text,
  );
}

Future<void> showMomentErrorPopup(
  BuildContext context, {
  required OrbitPopupCallback onRetry,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.momentError,
    title: 'Something Went Wrong',
    description: "You can't complete your Moment",
    assetPath: 'assets/popup/warning.svg',
    motion: OrbitPopupIllustrationMotion.warningPulse,
    illustrationSvgSize: 88,
    primaryLabel: 'Try Again',
    onPrimary: onRetry,
  );
}

Future<void> showLoadingPopup(
  BuildContext context, {
  bool showCloseButton = false,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.loading,
    title: 'Loading...',
    description: 'Please Wait a Moment',
    assetPath: 'assets/popup/reload.svg',
    motion: OrbitPopupIllustrationMotion.reload,
    illustrationSvgSize: 94,
    showCloseButton: showCloseButton,
  );
}

Future<void> showBatteryOptimizationPopup(
  BuildContext context, {
  required OrbitPopupCallback onContinue,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.batteryOptimization,
    title: 'Battery Optimization Education',
    description:
        'Orbit is Optimized to use minimal battery. You can review settings.',
    assetPath: 'assets/popup/battery.svg',
    motion: OrbitPopupIllustrationMotion.batteryEntry,
    illustrationSvgSize: 86,
    primaryLabel: 'Continue',
    onPrimary: onContinue,
  );
}

Future<void> showMicrophonePermissionPopup(
  BuildContext context, {
  required OrbitPopupCallback onAllow,
  OrbitPopupCallback? onNotNow,
}) {
  return _showConfiguredPopup(
    context,
    type: OrbitPopupType.microphonePermission,
    title: 'Allow Microphone Access',
    description: 'Orbit needs Microphone access to Record moments',
    assetPath: 'assets/popup/microphone.svg',
    motion: OrbitPopupIllustrationMotion.microphoneBreathe,
    illustrationSvgSize: 84,
    primaryLabel: 'Allow',
    onPrimary: onAllow,
    secondaryLabel: 'Not Now',
    onSecondary: onNotNow,
    secondaryStyle: OrbitPopupActionStyle.text,
  );
}

Future<void> _showConfiguredPopup(
  BuildContext context, {
  required OrbitPopupType type,
  required String title,
  required String assetPath,
  required OrbitPopupIllustrationMotion motion,
  String? description,
  String? primaryLabel,
  OrbitPopupCallback? onPrimary,
  OrbitPopupActionStyle primaryStyle = OrbitPopupActionStyle.gradient,
  String? secondaryLabel,
  OrbitPopupCallback? onSecondary,
  OrbitPopupActionStyle secondaryStyle = OrbitPopupActionStyle.text,
  bool showCloseButton = true,
  Color? illustrationBackground,
  double? illustrationBackgroundSize,
  double illustrationSvgSize = 82,
}) async {
  await showOrbitPopupModal<void>(
    context: context,
    popupId: type.name,
    barrierDismissible: false,
    builder: (dialogContext) => _ConfiguredOrbitPopup(
      key: OrbitPopupVariantKeys.popup(type),
      type: type,
      title: title,
      description: description,
      assetPath: assetPath,
      motion: motion,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      primaryStyle: primaryStyle,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      secondaryStyle: secondaryStyle,
      showCloseButton: showCloseButton,
      illustrationBackground: illustrationBackground,
      illustrationBackgroundSize: illustrationBackgroundSize,
      illustrationSvgSize: illustrationSvgSize,
    ),
  );
}

class _ConfiguredOrbitPopup extends StatefulWidget {
  const _ConfiguredOrbitPopup({
    required this.type,
    required this.title,
    required this.assetPath,
    required this.motion,
    required this.primaryStyle,
    required this.secondaryStyle,
    required this.showCloseButton,
    required this.illustrationSvgSize,
    this.description,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.illustrationBackground,
    this.illustrationBackgroundSize,
    super.key,
  });

  final OrbitPopupType type;
  final String title;
  final String? description;
  final String assetPath;
  final OrbitPopupIllustrationMotion motion;
  final String? primaryLabel;
  final OrbitPopupCallback? onPrimary;
  final OrbitPopupActionStyle primaryStyle;
  final String? secondaryLabel;
  final OrbitPopupCallback? onSecondary;
  final OrbitPopupActionStyle secondaryStyle;
  final bool showCloseButton;
  final Color? illustrationBackground;
  final double? illustrationBackgroundSize;
  final double illustrationSvgSize;

  @override
  State<_ConfiguredOrbitPopup> createState() => _ConfiguredOrbitPopupState();
}

class _ConfiguredOrbitPopupState extends State<_ConfiguredOrbitPopup> {
  bool _actionLocked = false;

  void _close() {
    if (_actionLocked) return;
    _actionLocked = true;
    Navigator.of(context).pop();
  }

  void _run(OrbitPopupCallback? callback) {
    if (_actionLocked) return;
    _actionLocked = true;
    Navigator.of(context).pop();
    if (callback != null) {
      scheduleMicrotask(() async {
        await Future<void>.sync(callback);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrbitPopupModal(
      title: widget.title,
      description: widget.description,
      showCloseButton: widget.showCloseButton,
      closeButtonKey: OrbitPopupVariantKeys.close(widget.type),
      onClose: _close,
      icon: OrbitPopupIllustration(
        assetPath: widget.assetPath,
        motion: widget.motion,
        width: 104,
        height: 104,
        svgWidth: widget.illustrationSvgSize,
        svgHeight: widget.illustrationSvgSize,
        backgroundColor: widget.illustrationBackground,
        backgroundSize: widget.illustrationBackgroundSize,
      ),
      iconToTitleGap: 20,
      titleToDescriptionGap: 20,
      contentToPrimaryGap: 20,
      primaryToSecondaryGap: 10,
      primaryAction: widget.primaryLabel == null
          ? null
          : KeyedSubtree(
              key: OrbitPopupVariantKeys.primary(widget.type),
              child: _actionButton(
                style: widget.primaryStyle,
                label: widget.primaryLabel!,
                onPressed: () => _run(widget.onPrimary),
              ),
            ),
      secondaryAction: widget.secondaryLabel == null
          ? null
          : KeyedSubtree(
              key: OrbitPopupVariantKeys.secondary(widget.type),
              child: _actionButton(
                style: widget.secondaryStyle,
                label: widget.secondaryLabel!,
                onPressed: () => _run(widget.onSecondary),
              ),
            ),
    );
  }

  Widget _actionButton({
    required OrbitPopupActionStyle style,
    required String label,
    required VoidCallback onPressed,
  }) {
    switch (style) {
      case OrbitPopupActionStyle.gradient:
        return OrbitPopupPrimaryButton(label: label, onPressed: onPressed);
      case OrbitPopupActionStyle.secondary:
        return OrbitPopupSecondaryButton(label: label, onPressed: onPressed);
      case OrbitPopupActionStyle.destructive:
        return OrbitPopupDestructiveButton(label: label, onPressed: onPressed);
      case OrbitPopupActionStyle.text:
        return OrbitPopupTextButton(label: label, onPressed: onPressed);
    }
  }
}
