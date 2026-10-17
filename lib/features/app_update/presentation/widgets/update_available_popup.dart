import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/popups/orbit_popup.dart';
import '../../domain/models/update_popup_data.dart';

abstract final class UpdateAvailablePopupKeys {
  static const popup = Key('update_available_popup');
  static const icon = Key('update_available_popup_icon');
  static const versionRow = Key('update_available_popup_versions');
  static const whatsNew = Key('update_available_popup_whats_new');
  static const updateNow = Key('update_available_popup_update_now');
  static const later = Key('update_available_popup_later');

  static Key change(int index) => Key('update_available_popup_change_$index');
}

Future<UpdatePopupResult?> showUpdateAvailablePopup(
  BuildContext context, {
  UpdatePopupData data = UpdatePopupData.demo,
}) {
  return showOrbitPopupModal<UpdatePopupResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => UpdateAvailablePopup(
      key: UpdateAvailablePopupKeys.popup,
      data: data,
      onLater: data.isForceUpdate
          ? null
          : () => Navigator.of(dialogContext).pop(UpdatePopupResult.later),
      onUpdated: () =>
          Navigator.of(dialogContext).pop(UpdatePopupResult.updateNow),
    ),
  );
}

class UpdateAvailablePopup extends StatefulWidget {
  const UpdateAvailablePopup({
    required this.data,
    required this.onUpdated,
    this.onLater,
    super.key,
  });

  final UpdatePopupData data;
  final VoidCallback onUpdated;
  final VoidCallback? onLater;

  @override
  State<UpdateAvailablePopup> createState() => _UpdateAvailablePopupState();
}

class _UpdateAvailablePopupState extends State<UpdateAvailablePopup> {
  bool _isUpdating = false;

  Future<void> _handleUpdateNow() async {
    if (_isUpdating) {
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final action = widget.data.updateAction;
      if (action != null) {
        await action();
      }
      if (!mounted) {
        return;
      }
      widget.onUpdated();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isUpdating = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    return OrbitPopupModal(
      title: data.title,
      description: data.description,
      icon: OrbitPopupHeaderIcon(
        child: SvgPicture.asset(
          'assets/popup/update.svg',
          key: UpdateAvailablePopupKeys.icon,
          width: 54,
          height: 54,
          fit: BoxFit.contain,
        ),
      ),
      metadata: _VersionSection(
        currentVersion: data.currentVersion,
        newVersion: data.newVersion,
      ),
      content: _WhatsNewSection(changes: data.changes),
      primaryAction: KeyedSubtree(
        key: UpdateAvailablePopupKeys.updateNow,
        child: OrbitPopupPrimaryButton(
          label: _isUpdating ? 'Updating...' : 'Update Now',
          enabled: !_isUpdating,
          onPressed: _handleUpdateNow,
        ),
      ),
      secondaryAction: widget.onLater == null
          ? null
          : KeyedSubtree(
              key: UpdateAvailablePopupKeys.later,
              child: OrbitSecondaryTextButton(
                label: 'Later',
                onPressed: widget.onLater!,
              ),
            ),
    );
  }
}

class _VersionSection extends StatelessWidget {
  const _VersionSection({
    required this.currentVersion,
    required this.newVersion,
  });

  final String currentVersion;
  final String newVersion;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: UpdateAvailablePopupKeys.versionRow,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: OrbitVersionBadge(label: currentVersion, emphasized: false),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Color(0xFFA0A7B3),
          ),
        ),
        Flexible(child: OrbitVersionBadge(label: newVersion, emphasized: true)),
      ],
    );
  }
}

class _WhatsNewSection extends StatelessWidget {
  const _WhatsNewSection({required this.changes});

  final List<String> changes;

  @override
  Widget build(BuildContext context) {
    final visibleChanges = changes
        .where((change) => change.trim().isNotEmpty)
        .toList();

    return OrbitPopupInfoSection(
      key: UpdateAvailablePopupKeys.whatsNew,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          OrbitGradientText(
            text: "WHAT'S NEW",
            style: AppTypography.body.copyWith(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          if (visibleChanges.isNotEmpty) const SizedBox(height: 8),
          for (
            var index = 0;
            index < visibleChanges.length;
            index++
          ) ...<Widget>[
            _FeatureRow(
              key: UpdateAvailablePopupKeys.change(index),
              text: visibleChanges[index],
            ),
            if (index != visibleChanges.length - 1) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: OrbitGradientBullet(size: 6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(
              color: OrbitPopupTokens.darkText,
              fontSize: 12,
              height: 16.8 / 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}
