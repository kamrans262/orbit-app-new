/// Independent client-side M7 rollout gate. The Laravel flag and the user's
/// M3 privacy permissions remain additional, authoritative requirements.
/// Release builds default to OFF; opt in only for approved M7 testing with
/// --dart-define=ORBIT_M7_MOMENTS_ENABLED=true.
abstract final class OrbitM7Rollout {
  static const bool enabled=bool.fromEnvironment(
    'ORBIT_M7_MOMENTS_ENABLED',defaultValue:false);
}
