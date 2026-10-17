import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/direct_chat/presentation/screens/direct_chat_screen.dart';

void main() {
  Future<void> pumpAtSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: DirectChatScreen.demo()));
    await tester.pumpAndSettle();
  }

  testWidgets('direct chat is responsive on compact phone', (tester) async {
    await pumpAtSize(tester, const Size(320, 568));

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Daisy'), findsOneWidget);
    expect(find.text('View map'), findsOneWidget);
    expect(find.byKey(DirectChatScreenKeys.scroll), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('composer sends a dynamic text message', (tester) async {
    await pumpAtSize(tester, const Size(390, 844));

    final field = find.byKey(const Key('direct_chat_text_field'));
    await tester.enterText(field, 'Dynamic backend-ready message');
    await tester.pump();
    await tester.tap(find.byKey(const Key('direct_chat_send_button')));
    await tester.pumpAndSettle();

    expect(find.text('Dynamic backend-ready message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
