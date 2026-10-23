import 'dart:async';

/// Transport-neutral M5 invalidation contract. Implementations may be added
/// after an approved authenticated transport is configured (Firebase later).
/// No member roster, invitation code, location or protected content belongs
/// in the event payload. An invalidation never authorizes or mutates a Circle:
/// listeners must revalidate with the authenticated backend before display.
class OrbitCircleInvalidation {
  const OrbitCircleInvalidation({required this.circleId, required this.revision});
  final String circleId;
  final int revision;
}

abstract class OrbitCircleChangeSource {
  const OrbitCircleChangeSource();

  Stream<OrbitCircleInvalidation> get invalidations;

  /// No transport is connected in M5. Retain polling as the safe fallback.
  static const OrbitCircleChangeSource disabled = _DisabledCircleChangeSource();
}

class _DisabledCircleChangeSource extends OrbitCircleChangeSource {
  const _DisabledCircleChangeSource();
  @override
  Stream<OrbitCircleInvalidation> get invalidations => const Stream.empty();
}
