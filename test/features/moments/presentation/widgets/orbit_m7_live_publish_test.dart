import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/domain/models/moment_publish_models.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/moment_publish_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real M7 Only Me uses confirmed server ID, not a demo success',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final seen = <MomentPublishRequest>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        TextButton(onPressed: () => showMomentPublishingSheet(context,
          photoBytes: Uint8List.fromList(const [1, 2, 3]),
          circles: const [], privacyAudience: 'Nobody',
          publisher: (request, progress) async {
            seen.add(request);
            progress(1);
            return const MomentPublishReceipt(momentId: 'server-issued-m7-id');
          }), child: const Text('Open')))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Only Me'), findsWidgets);
    await tester.ensureVisible(find.text('Publish Moment'));
    await tester.tap(find.text('Publish Moment'));
    await tester.pumpAndSettle();
    expect(seen, hasLength(1));
    expect(seen.single.audienceKind, 'only_me');
    expect(seen.single.targetIds, isEmpty);
    expect(seen.single.clientId, isNotEmpty);
    expect(find.text('Your Moment is live'), findsOneWidget);
    expect(find.textContaining('Preview completed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing Orbit selector offers friend sharing only with privacy opt-in',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        TextButton(onPressed: () => showMomentPublishingSheet(context,
          photoBytes: Uint8List.fromList(const [1, 2, 3]),
          circles: const [], friends: const [
            MomentAudienceCircle(id: 'actual-id', name: 'Actual Friend'),
          ],
          privacyAudience: 'Selected People',
          publisher: (request, progress) async {
            return const MomentPublishReceipt(momentId: 'server-confirmed');
          }), child: const Text('Open')))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(MomentPublishKeys.chooseAudience));
    await tester.tap(find.byKey(MomentPublishKeys.chooseAudience));
    await tester.pumpAndSettle();
    expect(find.text('Selected Friends'), findsOneWidget);
    expect(find.text('All Friends'), findsOneWidget);
    expect(find.text('Selected Circles'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
