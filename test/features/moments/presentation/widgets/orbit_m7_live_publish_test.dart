import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/domain/models/moment_publish_models.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/moment_publish_sheet.dart';

void main() {
  final realPhoto=base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAOEGFykAAAAASUVORK5CYII=');
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real M7 Only Me uses confirmed server ID, not a demo success',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final seen = <MomentPublishRequest>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        TextButton(onPressed: () => showMomentPublishingSheet(context,
          photoBytes: realPhoto,
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
          photoBytes: realPhoto,
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
  testWidgets('M7 live sheet retains M6 private saving without publishing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var published = false;
    var saved = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        TextButton(onPressed: () => showMomentPublishingSheet(context,
          photoBytes: realPhoto,
          circles: const [], privacyAudience: 'Nobody',
          publisher: (request, progress) async {
            published = true;
            return const MomentPublishReceipt(momentId: 'server-confirmed');
          },
          privateSaver: (bytes, progress) async {
            saved = true;
            progress(1);
          }), child: const Text('Open')))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Publish Moment'), findsOneWidget);
    await tester.ensureVisible(find.text('Save privately without publishing'));
    await tester.tap(find.text('Save privately without publishing'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(published, isFalse);
    expect(find.text('Photo saved privately'), findsOneWidget);
  });

  testWidgets('M7 publishing plus M6 private save still exposes real audience choices',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:Builder(builder:(context)=>TextButton(
        onPressed:()=>showMomentPublishingSheet(context,
          photoBytes:realPhoto,
          circles:const [MomentAudienceCircle(id:'circle1',name:'Approved Circle')],
          friends:const [],privacyAudience:'My Circle',
          publisher:(request,progress) async =>
            const MomentPublishReceipt(momentId:'server-confirmed'),
          privateSaver:(bytes,progress) async {}),
        child:const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(MomentPublishKeys.chooseAudience),findsOneWidget);
    await tester.ensureVisible(find.byKey(MomentPublishKeys.chooseAudience));
    await tester.tap(find.byKey(MomentPublishKeys.chooseAudience));
    await tester.pumpAndSettle();
    final selected=find.text('Selected Circles');
    expect(selected,findsOneWidget);
    await tester.tap(selected);
    await tester.pump();
    await tester.ensureVisible(find.text('Approved Circle'));
    expect(find.text('Approved Circle'),findsOneWidget);
  });

  testWidgets('Video clip remains a video in the existing publish sheet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The sheet only carries the captured file reference; fake async widget
    // tests must not perform real filesystem I/O (which can deadlock).
    final source=File('orbit-m7-widget-video-test.mp4');
    MomentPublishRequest? captured;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:Builder(builder:(context)=>TextButton(
        onPressed:()=>showMomentPublishingSheet(context,
          photoBytes:Uint8List(0),mediaFile:source,mediaKind:'video',
          durationMs:5000,circles:const [],privacyAudience:'Nobody',
          publisher:(request,progress) async {
            captured=request;
            return const MomentPublishReceipt(momentId:'server-confirmed');
          }),child:const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Video ready to encrypt'),findsOneWidget);
    await tester.tap(find.text('Publish Moment'));
    await tester.pump();
    expect(captured?.mediaKind,'video');
    expect(captured?.durationMs,5000);
    expect(captured?.mediaFile?.path,source.path);
  });

}
