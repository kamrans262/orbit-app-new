import 'package:flutter/material.dart';

import '../../../../core/popups/orbit_popup_modal.dart';

/// Uses approved Orbit modal, buttons, padding, animation and colors.
Future<bool> confirmOrbitSocialAction(BuildContext context, {
  required String title,
  required String description,
  required String confirmation,
  bool destructive = false,
  bool barrierDismissible = false,
}) async {
  final result = await showOrbitPopupModal<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialog) => OrbitPopupModal(
      title: title,
      description: description,
      primaryAction: destructive
        ? OrbitPopupDestructiveButton(
            label: confirmation,
            onPressed: () => Navigator.of(dialog).pop(true))
        : OrbitPopupPrimaryButton(
            label: confirmation,
            onPressed: () => Navigator.of(dialog).pop(true)),
      secondaryAction: OrbitPopupSecondaryButton(
        label: 'Cancel',
        onPressed: () => Navigator.of(dialog).pop(false)),
    ),
  );
  return result == true;
}
