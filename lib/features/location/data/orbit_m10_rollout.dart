abstract final class OrbitM10Rollout {
  static const enabled=bool.fromEnvironment('ORBIT_M10_LOCATION_ENABLED',defaultValue:false);
  static const mapStyleUrl=String.fromEnvironment('ORBIT_M10_MAP_STYLE_URL',defaultValue:'');
  static bool get mapConfigured=>mapStyleUrl.startsWith('https://');
}
