import 'package:flutter/material.dart';

import '../../domain/models/sos_models.dart';

class SosQuickActions extends StatelessWidget {
  const SosQuickActions({required this.onAction, super.key});

  final ValueChanged<SosQuickActionType> onAction;

  static const List<_SosQuickActionData> _actions = <_SosQuickActionData>[
    _SosQuickActionData(
      type: SosQuickActionType.emergencyContacts,
      label: 'Emergency\nContacts',
      icon: Icons.phone_in_talk_outlined,
    ),
    _SosQuickActionData(
      type: SosQuickActionType.shareLocation,
      label: 'Share\nLocation',
      icon: Icons.location_on_outlined,
    ),
    _SosQuickActionData(
      type: SosQuickActionType.recordAudio,
      label: 'Record\nAudio',
      icon: Icons.mic_none_rounded,
    ),
    _SosQuickActionData(
      type: SosQuickActionType.callEmergency,
      label: 'Call\n911',
      icon: Icons.phone_in_talk_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _actions
          .map(
            (_SosQuickActionData action) => Expanded(
              child: _SosQuickActionItem(
                data: action,
                onTap: () => onAction(action.type),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SosQuickActionItem extends StatelessWidget {
  const _SosQuickActionItem({required this.data, required this.onTap});

  final _SosQuickActionData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: data.label.replaceAll('\n', ' '),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x1F1A1A1A),
                  border: Border.all(width: 1, color: const Color(0xFF2A2A2A)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  data.icon,
                  size: 27,
                  color: const Color(0xE6FFFFFF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: Color(0xA6FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosQuickActionData {
  const _SosQuickActionData({
    required this.type,
    required this.label,
    required this.icon,
  });

  final SosQuickActionType type;
  final String label;
  final IconData icon;
}
