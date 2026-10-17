import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';

void main() {
  testWidgets('Favorite Circle member opens Friend Details', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pumpAndSettle();

    final member = find.byKey(const ValueKey<String>('favorite_emma'));
    final scrollable = find.byType(CustomScrollView);

    expect(member, findsOneWidget);
    expect(scrollable, findsOneWidget);

    if (member.hitTestable().evaluate().isEmpty) {
      await tester.dragUntilVisible(member, scrollable, const Offset(0, -220));
      await tester.ensureVisible(member);
      await tester.pumpAndSettle();
    }

    final tappableMember = member.hitTestable();
    expect(tappableMember, findsOneWidget);
    await tester.tap(tappableMember);
    await tester.pumpAndSettle();

    expect(find.text('Friend Details'), findsOneWidget);
  });
}
