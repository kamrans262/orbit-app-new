import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_bottom_navigation_bar.dart';

void main() {
  testWidgets('bottom navigation renders four SVG assets and keeps callbacks', (
    tester,
  ) async {
    var selected = -1;
    var addPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedIndex: 0,
            onTabSelected: (index) => selected = index,
            onAddPressed: () => addPressed = true,
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsNWidgets(4));
    await tester.tap(find.text('Moments'));
    await tester.pump();
    expect(selected, 2);

    await tester.tap(find.bySemanticsLabel('Add'));
    await tester.pump();
    expect(addPressed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
