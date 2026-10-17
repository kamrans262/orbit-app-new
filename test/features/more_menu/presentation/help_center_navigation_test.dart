import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/help_center/presentation/screens/help_center_screen.dart';
import 'package:orbit_ui/features/more_menu/presentation/screens/more_menu_screen.dart';

void main() {
  testWidgets('More menu Help Center opens the complete HelpCenterScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 866);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MoreMenuScreen()));
    await tester.pumpAndSettle();

    final helpTile = find.byKey(MoreMenuKeys.tile('help_center'));
    expect(helpTile, findsOneWidget);
    expect(helpTile.hitTestable(), findsOneWidget);

    await tester.tap(helpTile.hitTestable());
    await tester.pumpAndSettle();

    expect(find.byType(HelpCenterScreen), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
  });
}
