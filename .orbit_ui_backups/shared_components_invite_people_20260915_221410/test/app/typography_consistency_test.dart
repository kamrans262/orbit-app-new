import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';

void main() {
  test('large heading typography is consistent project-wide', () {
    expect(AppTypography.fontFamily, 'Poppins');
    expect(AppTypography.largeHeading.fontSize, 29);
    expect(AppTypography.largeHeading.fontWeight, FontWeight.w600);
  });
}
