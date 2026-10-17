import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/direct_chat/presentation/screens/direct_chat_screen.dart';
import 'package:orbit_ui/features/orbit/presentation/screens/orbit_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('person tap stays on Orbit composer and Send opens Direct Chat', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: OrbitScreen.demo()));
    await tester.pumpAndSettle();

    final suzie = find.byKey(OrbitKeys.person('suzie'));
    expect(suzie, findsOneWidget);

    expect(
      find.descendant(of: suzie, matching: find.byType(InkResponse)),
      findsNothing,
    );

    await tester.tap(suzie);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DirectChatScreen), findsNothing);
    expect(find.byKey(OrbitKeys.expandedHeader), findsOneWidget);
    expect(find.text('Suzie'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Message Suzie'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Message Suzie'),
      'On my way',
    );
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DirectChatScreen), findsOneWidget);
    expect(find.text('On my way'), findsWidgets);
  });
}
