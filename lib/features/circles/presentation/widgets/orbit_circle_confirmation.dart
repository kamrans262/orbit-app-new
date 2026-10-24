import 'package:flutter/material.dart';

import '../../../../core/popups/orbit_popup_modal.dart';

/// Confirmation for M5 Circle actions. Uses the existing Orbit popup design.
Future<bool> showOrbitCircleConfirmation({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final approved = await showOrbitPopupModal<bool>(
    context: context,
    builder: (dialogContext) => OrbitPopupModal(
      title: title,
      description: description,
      primaryAction: destructive
          ? OrbitPopupDestructiveButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            )
          : OrbitPopupPrimaryButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
      secondaryAction: OrbitPopupTextButton(
        label: cancelLabel,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
    ),
  );
  return approved == true;
}
