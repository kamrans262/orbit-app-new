import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/popups/orbit_popup.dart';

enum NoMomentsPopupResult { createMoment, dismissed }

abstract final class NoMomentsPopupKeys {
  static const popup = Key('no_moments_popup');
  static const illustration = Key('no_moments_popup_illustration');
  static const close = Key('no_moments_popup_close');
  static const createMoment = Key('no_moments_popup_create_moment');
}

Future<NoMomentsPopupResult?> showNoMomentsPopup(
  BuildContext context, {
  required VoidCallback onCreateMoment,
}) async {
  final result = await showOrbitPopupModal<NoMomentsPopupResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => NoMomentsPopup(
      key: NoMomentsPopupKeys.popup,
      onClose: () =>
          Navigator.of(dialogContext).pop(NoMomentsPopupResult.dismissed),
      onCreateMoment: () =>
          Navigator.of(dialogContext).pop(NoMomentsPopupResult.createMoment),
    ),
  );

  if (result == NoMomentsPopupResult.createMoment) {
    onCreateMoment();
  }
  return result;
}

class NoMomentsPopup extends StatelessWidget {
  const NoMomentsPopup({
    required this.onClose,
    required this.onCreateMoment,
    super.key,
  });

  final VoidCallback onClose;
  final VoidCallback onCreateMoment;

  @override
  Widget build(BuildContext context) {
    return OrbitPopupModal(
      title: 'No moments Yet',
      description: 'Share your first moment with your circle',
      showCloseButton: true,
      onClose: onClose,
      closeButtonKey: NoMomentsPopupKeys.close,
      icon: SizedBox(
        width: 100,
        height: 100,
        child: SvgPicture.asset(
          'assets/popup/m1.svg',
          key: NoMomentsPopupKeys.illustration,
          fit: BoxFit.contain,
        ),
      ),
      iconToTitleGap: 20,
      titleToDescriptionGap: 20,
      contentToPrimaryGap: 20,
      primaryAction: KeyedSubtree(
        key: NoMomentsPopupKeys.createMoment,
        child: OrbitPopupPrimaryButton(
          label: 'Create Moment',
          onPressed: onCreateMoment,
        ),
      ),
    );
  }
}
