/// M10 foreground UI is ON for plain `flutter run`. Google Maps uses separately
/// restricted native SDK keys in untracked Android/iOS files.
/// The server, GPS permissions, Ghost Mode and consent still gate all sharing.
/// Keep key values in untracked platform files, never in Dart defines or Git.
abstract final class OrbitM10Rollout {
  static const enabled=bool.fromEnvironment(
    'ORBIT_M10_LOCATION_ENABLED',defaultValue:true);
  static const googleMapsConfigured=bool.fromEnvironment(
    'ORBIT_M10_GOOGLE_MAPS_CONFIGURED',defaultValue:true);
  static const realtimeSocketUrl=String.fromEnvironment(
    'ORBIT_M10_WSS_URL',defaultValue:'');
  static bool get realtimeConfigured=>realtimeSocketUrl.startsWith('wss://');
  static bool get mapConfigured=>googleMapsConfigured;
}
