import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/data/orbit_m5_firebase_change_source.dart';

void main() {
  test('M5 Firebase is compiled but disabled and never requests credentials', () async {
    // Normal debug/release builds must not contact Firebase or download a
    // token until explicitly built with the enable dart-define and approved
    // by the existing authenticated Orbit backend.
    expect(OrbitM5FirebaseChangeSource.compiledEnabled, isFalse);
    var bootstrapCalls = 0;
    final runtime = OrbitM5FirebaseChangeSource.instance;
    runtime.setBootstrap(() async {
      bootstrapCalls++;
      throw StateError('Disabled Firebase must never request a ticket.');
    });
    await runtime.watchCircles(
      ['00000000-0000-4000-8000-000000000001'],
    );
    expect(bootstrapCalls, 0);
    await runtime.stop();
  });
}
