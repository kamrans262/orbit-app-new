import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_stickers.dart';
import 'package:orbit_ui/features/messaging/presentation/orbit_chat_expression_picker.dart';

void main(){
  test('Sticker manifests are ID-only encrypted content, not URLs',(){
    const item=OrbitChatSticker('orbit-heart');
    final value=item.encode();
    expect(value,contains('orbit_m13_sticker'));
    expect(value,contains('orbit-heart'));
    expect(value, isNot(contains('http')));
    expect(value, isNot(contains('ciphertext_url')));
    expect(OrbitChatSticker.tryParse(value)?.id,'orbit-heart');
    expect(OrbitChatSticker.tryParse('hello'),isNull);
    expect(OrbitChatSticker.tryParse(
      '{"v":1,"type":"orbit_m13_sticker","id":"external-url"}'),isNull);
  });

  testWidgets('Approved Orbit sheet sends sticker artwork IDs separately from emoji',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:Builder(builder:(context)=>TextButton(
        onPressed:() async {
          selected=await showOrbitChatExpressionPicker(context);
        },
        child:const Text('Expressions'),
      ))),
    ));
    await tester.tap(find.text('Expressions'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orbit_circle_sheet_surface')),findsOneWidget);
    expect(find.byKey(const Key('orbit_sticker_grid')),findsOneWidget);
    await tester.tap(find.byKey(const Key('orbit_sticker_orbit-heart')));
    await tester.pumpAndSettle();
    expect(OrbitChatSticker.tryParse(selected)?.id,'orbit-heart');

    await tester.tap(find.text('Expressions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emoji'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orbit_emoji_grid')),findsOneWidget);
    await tester.tap(find.byKey(const Key('orbit_emoji_0')));
    await tester.pumpAndSettle();
    expect(selected,'😀');
    expect(OrbitChatSticker.tryParse(selected),isNull);
  });
}
