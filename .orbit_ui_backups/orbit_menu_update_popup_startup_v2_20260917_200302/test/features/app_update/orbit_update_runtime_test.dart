import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/app_update/presentation/orbit_update_runtime.dart';

void main() {
  test('version comparison only reports genuinely newer releases', () {
    expect(isOrbitVersionNewer('2.5.0', '2.4.1'), isTrue);
    expect(isOrbitVersionNewer('v2.5.0', '2.5.0'), isFalse);
    expect(isOrbitVersionNewer('2.5.1+9', '2.5.0+30'), isTrue);
    expect(isOrbitVersionNewer('2.4.9', '2.5.0'), isFalse);
  });
}
