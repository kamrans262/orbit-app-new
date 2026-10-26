/// Client rollout never bypasses the backend trusted-device gate.
abstract final class OrbitM8Rollout {
  static const bool enabled=bool.fromEnvironment('ORBIT_M8_DASHBOARD_ENABLED',defaultValue:false);
}
