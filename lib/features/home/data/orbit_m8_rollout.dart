/// ON by default for the consolidated app: plain flutter run uses M8 Home.
/// The Laravel trusted-device and per-resource permissions remain authoritative.
/// Explicit rollback: --dart-define=ORBIT_M8_DASHBOARD_ENABLED=false.
abstract final class OrbitM8Rollout {
  static const bool enabled=bool.fromEnvironment('ORBIT_M8_DASHBOARD_ENABLED',defaultValue:true);
}
