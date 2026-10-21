import 'package:flutter/material.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../welcome/presentation/screens/create_circle_screen.dart';
import '../../data/orbit_circle_repository.dart';
import 'orbit_live_circle_detail_screen.dart';

class OrbitLiveCreateCircleScreen extends StatelessWidget {
  const OrbitLiveCreateCircleScreen({super.key, this.repository, this.onCreated});
  final OrbitCircleRepository? repository;
  final ValueChanged<OrbitCircle>? onCreated;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? OrbitCircleRepository();
    OrbitCircle? created;
    return CreateCircleScreen(
      onCreateRequested: (name,color,icon,key) async {
        created = await repo.create(name,color:color,icon:icon,idempotencyKey:key);
        onCreated?.call(created!);
      },
      onNext: () {
        final circle = created;
        if (circle == null) return;
        // No simulated permission approval; explicit sharing remains OFF.
        Navigator.of(context).pushReplacement<void,void>(
          AppFadeSlidePageRoute<void>(builder: (_) =>
            OrbitLiveCircleDetailScreen(circleId: circle.id,repository: repo)),
        );
      },
      onSkip: () => Navigator.of(context).maybePop(),
    );
  }
}
