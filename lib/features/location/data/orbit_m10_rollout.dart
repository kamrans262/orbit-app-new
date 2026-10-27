/// M10 stays opt-in. Set these only in a local/CI secret environment;
/// never add provider credentials to tracked source files.
abstract final class OrbitM10Rollout {
  static const enabled=bool.fromEnvironment('ORBIT_M10_LOCATION_ENABLED',defaultValue:false);
  static const mapStyleTemplate=String.fromEnvironment('ORBIT_M10_MAP_STYLE_URL',defaultValue:'');
  static const mapApiKey=String.fromEnvironment('ORBIT_M10_MAP_API_KEY',defaultValue:'');
  static bool get mapConfigured=>mapStyleTemplate.startsWith('https://') &&
      (!mapStyleTemplate.contains('{API_KEY}') || mapApiKey.isNotEmpty);
  static String get mapStyleUrl=>mapConfigured
      ?mapStyleTemplate.replaceAll('{API_KEY}',Uri.encodeComponent(mapApiKey)):'';
}
