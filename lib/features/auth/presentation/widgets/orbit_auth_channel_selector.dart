import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Identity method picker: same Figma gradient, typography, pill radius,
/// white fill and subtle shadow as the existing Orbit form controls.
class OrbitAuthChannelSelector extends StatelessWidget {
  const OrbitAuthChannelSelector({
    required this.channel,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String channel;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final value in const ['email', 'sms']) ...[
          if (value == 'sms') const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              button: true,
              selected: channel == value,
              child: GestureDetector(
                key: Key('orbit_auth_channel_$value'),
                onTap: enabled ? () => onChanged(value) : null,
                child: Container(
                  height: AppTextField.referenceHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTextField.radius),
                    gradient: channel == value
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [AppColors.primaryStart, AppColors.primaryEnd],
                          )
                        : null,
                    color: channel == value ? null : AppColors.white,
                    boxShadow: const [
                      BoxShadow(
                        color: AppTextField.fieldShadowColor,
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    value == 'email' ? 'Email' : 'SMS',
                    style: AppTypography.button.copyWith(
                      color: channel == value
                          ? AppColors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
