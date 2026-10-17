import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/friends/presentation/screens/friends_screen.dart';

void main() {
  testWidgets('Friends search is overflow-safe at 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: FriendsScreen.demo()));

    await tester.tap(find.byKey(FriendsKeys.searchButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Emma');
    await tester.pump();

    expect(find.byKey(FriendsKeys.row('emma')), findsOneWidget);
    expect(find.text('Mike'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
