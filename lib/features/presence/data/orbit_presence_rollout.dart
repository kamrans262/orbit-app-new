/// M9 client runtime is available with plain `flutter run`. Backend privacy
/// gates and explicit sharing consent remain authoritative. A missing approved
/// WSS URL prevents socket connection and cannot claim realtime presence.
abstract final class OrbitPresenceRollout {
  static const bool enabled =
      bool.fromEnvironment('ORBIT_M9_PRESENCE_ENABLED', defaultValue: true);
  static const String websocketUrl =
      String.fromEnvironment('ORBIT_M9_WSS_URL', defaultValue: '');

  static Uri? get secureGateway {
    if (!enabled || websocketUrl.isEmpty) return null;
    final uri=Uri.tryParse(websocketUrl);
    if (uri == null || uri.scheme != 'wss' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasFragment || uri.hasQuery) return null;
    return uri;
  }
}
