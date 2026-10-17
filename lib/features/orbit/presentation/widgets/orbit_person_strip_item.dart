import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/orbit_models.dart';
import 'orbit_person_avatar.dart';

class OrbitPersonStripItem extends StatelessWidget {
  const OrbitPersonStripItem({
    required this.person,
    required this.onTap,
    this.width = 82,
    super.key,
  });

  final OrbitPersonData person;
  final VoidCallback onTap;
  final double width;

  static Key nameKey(String personId) => Key('orbit_person_name_$personId');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${person.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OrbitPersonAvatar(person: person),
              const SizedBox(height: 6),
              SizedBox(
                height: 16,
                width: double.infinity,
                child: Center(
                  child: Text(
                    person.name,
                    key: nameKey(person.id),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
