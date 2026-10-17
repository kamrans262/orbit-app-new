import 'package:flutter/material.dart';

import '../../domain/models/orbit_models.dart';
import 'orbit_person_avatar.dart';

class OrbitMapMarker extends StatelessWidget {
  const OrbitMapMarker({required this.person, required this.onTap, super.key});

  final OrbitPersonData person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${person.name} on map',
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: SizedBox.square(
                dimension: 42,
                child: OrbitPersonAvatar(
                  person: person,
                  size: 42,
                  showNewBadge: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
