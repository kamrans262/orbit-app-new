import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/popups/orbit_popup.dart';

enum OrbitOfflinePopupResult { restored, dismissed }

abstract final class OrbitOfflinePopupKeys {
  static const popup = Key('orbit_offline_popup');
  static const illustration = Key('orbit_offline_popup_illustration');
  static const close = Key('orbit_offline_popup_close');
  static const retry = Key('orbit_offline_popup_retry');
}

Future<OrbitOfflinePopupResult?> showOrbitOfflinePopup(
  BuildContext context, {
  required Future<bool> Function() onRetry,
}) {
  return showOrbitPopupModal<OrbitOfflinePopupResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => OrbitOfflinePopup(
      key: OrbitOfflinePopupKeys.popup,
      onClose: () =>
          Navigator.of(dialogContext).pop(OrbitOfflinePopupResult.dismissed),
      onRetry: onRetry,
      onConnectionRestored: () =>
          Navigator.of(dialogContext).pop(OrbitOfflinePopupResult.restored),
    ),
  );
}

class OrbitOfflinePopup extends StatefulWidget {
  const OrbitOfflinePopup({
    required this.onClose,
    required this.onRetry,
    required this.onConnectionRestored,
    super.key,
  });

  final VoidCallback onClose;
  final Future<bool> Function() onRetry;
  final VoidCallback onConnectionRestored;

  @override
  State<OrbitOfflinePopup> createState() => _OrbitOfflinePopupState();
}

class _OrbitOfflinePopupState extends State<OrbitOfflinePopup> {
  bool _isChecking = false;

  Future<void> _retry() async {
    if (_isChecking) {
      return;
    }
    setState(() => _isChecking = true);

    var isOnline = false;
    try {
      isOnline = await widget.onRetry();
    } on Object {
      isOnline = false;
    }

    if (!mounted) {
      return;
    }
    if (isOnline) {
      widget.onConnectionRestored();
      return;
    }
    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return OrbitPopupModal(
      title: 'You’re Offline',
      description: 'Check your connection and try again',
      showCloseButton: true,
      onClose: widget.onClose,
      closeButtonKey: OrbitOfflinePopupKeys.close,
      icon: SizedBox(
        width: 100,
        height: 100,
        child: SvgPicture.asset(
          'assets/popup/no_connection.svg',
          key: OrbitOfflinePopupKeys.illustration,
          fit: BoxFit.contain,
        ),
      ),
      iconToTitleGap: 20,
      titleToDescriptionGap: 20,
      contentToPrimaryGap: 20,
      primaryAction: KeyedSubtree(
        key: OrbitOfflinePopupKeys.retry,
        child: OrbitPopupPrimaryButton(
          label: _isChecking ? 'Checking…' : 'Try Again',
          enabled: !_isChecking,
          onPressed: _retry,
        ),
      ),
    );
  }
}
