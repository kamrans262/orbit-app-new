import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Moment feed and camera assets are bundled', () async {
    const assetPaths = <String>[
      'assets/moment_card.jpg',
      'assets/icons/close.svg',
      'assets/icons/filter.svg',
      'assets/icons/flash.svg',
      'assets/icons/flip.svg',
      'assets/icons/timer.svg',
      'assets/icons/sticker.svg',
      'assets/icons/text.svg',
    ];

    for (final assetPath in assetPaths) {
      final data = await rootBundle.load(assetPath);
      expect(data.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });
}
