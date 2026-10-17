import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../domain/models/request_models.dart';

abstract final class RequestCardKeys {
  static Key card(String id) => Key('request_card_$id');
  static Key accept(String id) => Key('request_accept_$id');
  static Key ignore(String id) => Key('request_ignore_$id');
  static Key avatarFallback(String id) => Key('request_avatar_fallback_$id');
}

class RequestCard extends StatelessWidget {
  const RequestCard({
    required this.data,
    required this.onAccept,
    required this.onIgnore,
    this.isBusy = false,
    super.key,
  });

  final RequestData data;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;
  final bool isBusy;

  static const double _radius = 16;
  static const double _innerPadding = 12;
  static const double _avatarSize = 46;
  static const double _buttonOuterInset = 31;
  static const double _buttonGap = 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: RequestCardKeys.card(data.id),
      width: double.infinity,
      padding: const EdgeInsets.all(_innerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _RequestAvatar(data: data),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _displayName(data.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontFamilyFallback: const <String>[
                            'Noto Color Emoji',
                            'Apple Color Emoji',
                            'Segoe UI Emoji',
                          ],
                          fontSize: 16,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displaySupportingText(data.supportingText),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontFamilyFallback: const <String>[
                            'Noto Color Emoji',
                            'Apple Color Emoji',
                            'Segoe UI Emoji',
                          ],
                          fontSize: 10,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _buttonOuterInset - _innerPadding,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AppPrimaryButton(
                    key: RequestCardKeys.accept(data.id),
                    label: 'Accept',
                    enabled: !isBusy,
                    onPressed: onAccept,
                  ),
                ),
                const SizedBox(width: _buttonGap),
                Expanded(
                  child: _IgnoreButton(
                    key: RequestCardKeys.ignore(data.id),
                    enabled: !isBusy,
                    onPressed: onIgnore,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _displayName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Unknown person' : trimmed;
  }

  static String _displaySupportingText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Sent you a request.' : trimmed;
  }
}

class _RequestAvatar extends StatelessWidget {
  const _RequestAvatar({required this.data});

  final RequestData data;

  @override
  Widget build(BuildContext context) {
    final path = data.imagePath?.trim();

    return SizedBox.square(
      dimension: RequestCard._avatarSize,
      child: ClipOval(
        child: path == null || path.isEmpty
            ? _AvatarFallback(data: data)
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(data: data),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.data});

  final RequestData data;

  @override
  Widget build(BuildContext context) {
    final trimmed = data.name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();

    return ColoredBox(
      key: RequestCardKeys.avatarFallback(data.id),
      color: const Color(0xFFF2EAFE),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }
}

class _IgnoreButton extends StatelessWidget {
  const _IgnoreButton({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final height = AppPrimaryButton.heightFor(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Ignore',
      child: Material(
        color: const Color(0xFFF2EFF8),
        borderRadius: BorderRadius.circular(AppPrimaryButton.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Center(
              child: Text(
                'Ignore',
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: const <String>[
                    'Noto Color Emoji',
                    'Apple Color Emoji',
                    'Segoe UI Emoji',
                  ],
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
