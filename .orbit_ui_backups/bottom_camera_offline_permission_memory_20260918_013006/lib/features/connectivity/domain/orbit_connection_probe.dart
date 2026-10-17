import 'dart:async';
import 'dart:io';

typedef OrbitConnectionCheck = Future<bool> Function();

/// Injectable connection probe used by Orbit's app-wide offline runtime.
///
/// The default check deliberately tries multiple independent DNS targets. A
/// single transient DNS failure must not make Orbit declare the device offline.
abstract final class OrbitConnectionProbe {
  static OrbitConnectionCheck check = _defaultCheck;

  static const List<String> _probeHosts = <String>[
    'one.one.one.one',
    'google.com',
    'example.com',
  ];

  static Future<bool> _defaultCheck() async {
    for (final host in _probeHosts) {
      try {
        final addresses = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 2));
        if (addresses.any((address) => address.rawAddress.isNotEmpty)) {
          return true;
        }
      } on Object {
        // Try the next independent target before deciding the device is offline.
      }
    }

    return false;
  }

  static void reset() {
    check = _defaultCheck;
  }
}
