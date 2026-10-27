/// M10 is off unless enabled. Google Maps uses separate native restricted keys.
/// Keep key values in untracked platform files, never in Dart defines or Git.
abstract final class OrbitM10Rollout {
  static const enabled=bool.fromEnvironment(
    'ORBIT_M10_LOCATION_ENABLED',defaultValue:false);
  static const googleMapsConfigured=bool.fromEnvironment(
    'ORBIT_M10_GOOGLE_MAPS_CONFIGURED',defaultValue:false);
  static const realtimeSocketUrl=String.fromEnvironment(
    'ORBIT_M10_WSS_URL',defaultValue:'');
  static bool get realtimeConfigured=>realtimeSocketUrl.startsWith('wss://');
  static bool get mapConfigured=>googleMapsConfigured;
}
