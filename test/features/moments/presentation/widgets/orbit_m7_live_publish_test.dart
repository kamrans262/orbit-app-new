import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/features/moments/domain/models/moment_publish_models.dart';
import 'package:orbit_ui/features/moments/data/orbit_capture_inspection.dart';
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
          durationMs:5000,enableNativePreview:false,
          circles:const [],privacyAudience:'Nobody',
          publisher:(request,progress) async {
            captured=request;
            return const MomentPublishReceipt(momentId:'server-confirmed');
          }),child:const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Video preview'),findsOneWidget);
    expect(find.text('Video ready to encrypt'),findsNothing);
    expect(tester.getTopLeft(find.text('Publish Moment')).dy,
      lessThan(tester.getTopLeft(find.byKey(MomentPublishKeys.chooseAudience)).dy));
    expect(tester.getTopLeft(find.byKey(MomentPublishKeys.chooseAudience)).dy,
      lessThan(tester.getTopLeft(find.text('Retake / Back to Camera')).dy));
    await tester.tap(find.text('Publish Moment'));
    await tester.pump();
    expect(captured?.mediaKind,'video');
    expect(captured?.durationMs,5000);
    expect(captured?.mediaFile?.path,source.path);
  });


  testWidgets('video settings and capture ID survive Back to Review and actual retry',(tester)async{
    await tester.binding.setSurfaceSize(const Size(390,844));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    final source=File('orbit-m7-retry-video.mp4');
    final requests=<MomentPublishRequest>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>
      TextButton(onPressed:()=>showMomentPublishingSheet(context,
        photoBytes:Uint8List(0),mediaFile:source,mediaKind:'video',
        durationMs:5000,enableNativePreview:false,circles:const [],
        privacyAudience:'Nobody',publisher:(request,progress)async{
          requests.add(request);
          if(requests.length==1)throw const OrbitVideoPreparationFailure('poster','thumbnail_failed');
          if(requests.length==2)throw const FormatException('Export interrupted');
          return const MomentPublishReceipt(momentId:'server-confirmed-video');
        }),child:const Text('Open'))))));
    await tester.tap(find.text('Open'));await tester.pumpAndSettle();
    final saver=find.text('Save mobile data'),mute=find.text('Mute video audio');
    await tester.ensureVisible(saver);await tester.tap(saver);await tester.pumpAndSettle();
    await tester.ensureVisible(mute);await tester.tap(mute);await tester.pumpAndSettle();
    await tester.tap(find.text('Publish Moment'));await tester.pumpAndSettle();
    expect(find.text('Publishing interrupted'),findsOneWidget);
    expect(find.textContaining('could not create the video preview'),findsOneWidget);
    await tester.tap(find.text('Back to Review'));await tester.pumpAndSettle();
    await tester.ensureVisible(mute);
    expect(tester.widget<SwitchListTile>(find.ancestor(of:mute,matching:find.byType(SwitchListTile))).value,true);
    await tester.tap(find.text('Publish Moment'));await tester.pumpAndSettle();
    await tester.tap(find.byKey(MomentPublishKeys.retry));await tester.pumpAndSettle();
    expect(requests.length,3);
    expect(requests.map((r)=>r.clientId).toSet().length,1);
    expect(requests.every((r)=>r.mediaFile?.path==source.path&&r.dataSaver&&r.muteVideo),true);
    expect(find.text('Your Moment is live'),findsOneWidget);
  });

  testWidgets('rate limited publication blocks retries until cooldown, reuses client ID',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <MomentPublishRequest>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showMomentPublishingSheet(context,
          photoBytes: realPhoto,
          circles: const [], privacyAudience: 'Nobody',
          publisher: (request, progress) async {
            requests.add(request);
            if (requests.length == 1) {
              throw OrbitIdentityException('Too many requests', 429,
                const Duration(seconds: 10));
            }
            return const MomentPublishReceipt(momentId: 'confirmed-retry');
          }),
        child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Save privately'), findsNothing);
    expect(find.text('Save privately without publishing'), findsNothing);
    await tester.ensureVisible(find.text('Publish Moment'));
    await tester.tap(find.text('Publish Moment'));
    await tester.pumpAndSettle();
    final retry = find.byKey(MomentPublishKeys.retry);
    expect(tester.widget<AppPrimaryButton>(retry).enabled, isFalse);
    await tester.tap(retry);
    await tester.pump();
    expect(requests, hasLength(1));
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(tester.widget<AppPrimaryButton>(retry).enabled, isTrue);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.last.clientId, requests.first.clientId);
    expect(find.text('Your Moment is live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
