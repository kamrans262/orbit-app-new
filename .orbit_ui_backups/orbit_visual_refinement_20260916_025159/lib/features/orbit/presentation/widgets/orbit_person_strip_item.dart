import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/orbit_models.dart';
import 'orbit_person_avatar.dart';

class OrbitPersonStripItem extends StatelessWidget {
  const OrbitPersonStripItem({
    required this.person,
    required this.onTap,
    super.key,
  });

  final OrbitPersonData person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${person.name}',
      child: InkResponse(
        onTap: onTap,
        radius: 52,
        child: SizedBox(
          width: 82,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OrbitPersonAvatar(person: person),
              const SizedBox(height: 6),
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF0F1724),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
