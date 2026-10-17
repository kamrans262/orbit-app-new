import 'package:shared_preferences/shared_preferences.dart';

/// Stores whether Orbit has successfully initialized the device camera before.
///
/// The flag is written only after CameraController.initialize() succeeds.
/// Therefore:
/// - first use: Orbit education popup is shown
/// - user allows access and camera starts: flag becomes true
/// - later uses: Orbit education popup is skipped
/// - if camera access never succeeds, the education popup can still be shown
abstract final class OrbitCameraPermissionMemory {
  static const String _confirmedKey =
      'orbit_camera_access_successfully_confirmed_v1';

  static Future<bool> hasConfirmedCameraAccess() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_confirmedKey) ?? false;
  }

  static Future<void> markCameraAccessConfirmed() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_confirmedKey, true);
  }

  static Future<void> resetForTestingOrPermissionRecovery() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_confirmedKey);
  }
}
