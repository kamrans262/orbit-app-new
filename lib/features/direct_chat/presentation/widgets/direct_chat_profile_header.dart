import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/direct_chat_models.dart';

class DirectChatProfileHeader extends StatelessWidget {
  const DirectChatProfileHeader({required this.person, super.key});

  final DirectChatPerson person;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            SizedBox.square(dimension: 40, child: ClipOval(child: _avatar())),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: person.isOnline
                      ? const Color(0xFF10B981)
                      : const Color(0xFF94A3B8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1724),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                      ).createShader(bounds),
                      child: Text(
                        person.statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar() {
    final path = person.avatarPath?.trim();
    if (path == null || path.isEmpty) return _fallback();
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() {
    final trimmed = person.name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    return ColoredBox(
      color: const Color(0xFFE8DDF8),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
    );
  }
}
