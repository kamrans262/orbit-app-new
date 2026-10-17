import 'dart:async';
import 'dart:io';

typedef OrbitConnectionCheck = Future<bool> Function();

/// Injectable connection probe used by Orbit's app-wide offline runtime.
///
/// UI/tests can replace [check] without changing popup code. The default probe
/// performs a small DNS lookup and treats any exception/timeout as offline.
abstract final class OrbitConnectionProbe {
  static OrbitConnectionCheck check = _defaultCheck;

  static Future<bool> _defaultCheck() async {
    try {
      final addresses = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));
      return addresses.any((address) => address.rawAddress.isNotEmpty);
    } on Object {
      return false;
    }
  }

  static void reset() {
    check = _defaultCheck;
  }
}
