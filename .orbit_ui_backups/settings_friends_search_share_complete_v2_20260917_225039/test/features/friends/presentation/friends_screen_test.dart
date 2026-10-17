import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/friends/presentation/screens/friends_screen.dart';

void main() {
  testWidgets('Friends filters safely on 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: FriendsScreen.demo()));

    expect(find.text('Friends'), findsOneWidget);

    await tester.tap(find.byKey(FriendsKeys.searchButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Emma');
    await tester.pump();

    expect(find.text('Emma'), findsOneWidget);
    expect(find.text('Mike'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
