import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/presentation/screens/moment_camera_screen.dart';
import 'package:orbit_ui/features/moments/data/moment_photo_processor.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/moment_publish_sheet.dart';

void main() {
  testWidgets('M7 gallery photo uses approved Orbit camera without a second design',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo=Uint8List.fromList(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAOEGFykAAAAASUVORK5CYII='));
    Uint8List? received;
    await tester.pumpWidget(MaterialApp(home:MomentCameraScreen(
      enableCamera:false,
      galleryPicker:() async=>photo,
      onCaptured:(bytes)=>received=bytes,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MomentCameraKeys.galleryButton));
    await tester.pumpAndSettle();
    expect(received,orderedEquals(photo));
    expect(find.byKey(MomentCameraKeys.capturedPreview),findsOneWidget);
  });
  testWidgets('M7 video/voice camera modes expose hold-to-record without inventing a new camera',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home:MomentCameraScreen(
      enableCamera:false,
    )));
    await tester.pump();
    expect(find.bySemanticsLabel('Capture moment'),findsOneWidget);
    await tester.tap(find.byKey(MomentCameraKeys.videoMode));
    await tester.pump();
    expect(find.bySemanticsLabel('Hold to record moment'),findsOneWidget);
    await tester.tap(find.byKey(MomentCameraKeys.voiceMode));
    await tester.pump();
    expect(find.bySemanticsLabel('Hold to record moment'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('filters open over live preview without auto-capturing or publishing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo=Uint8List.fromList(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAOEGFykAAAAASUVORK5CYII='));
    var galleryReads=0;
    await tester.pumpWidget(MaterialApp(home:MomentCameraScreen(
      enableCamera:false,
      galleryPicker:()async {galleryReads++;return photo;},
    )));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.filterButton));
    await tester.pump();
    expect(find.byKey(MomentCameraKeys.filterTray),findsOneWidget);
    expect(find.byKey(MomentCameraKeys.capturedPreview),findsNothing);
    expect(find.byType(MomentPublishSheet),findsNothing);
    expect(galleryReads,0);
    await tester.tap(find.byKey(MomentCameraKeys.filter(MomentFilter.warm.name)));
    await tester.pump();
    final selected=tester.widget<ChoiceChip>(
        find.byKey(MomentCameraKeys.filter(MomentFilter.warm.name)));
    expect(selected.selected,isTrue);
    expect(find.byKey(MomentCameraKeys.capturedPreview),findsNothing);
    await tester.tap(find.byKey(const Key('moment_camera_close_filters')));
    await tester.pump();
    expect(find.byKey(MomentCameraKeys.filterTray),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('camera filter reaches secure photo editor with original bytes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo=Uint8List.fromList(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC0lEQVR42mP8/x8AAwMCAOEGFykAAAAASUVORK5CYII='));
    await tester.pumpWidget(MaterialApp(home:MomentCameraScreen(
      enableCamera:false,galleryPicker:()async=>photo,
    )));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.filterButton));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.filter(MomentFilter.cool.name)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('moment_camera_close_filters')));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.galleryButton));
    await tester.pumpAndSettle();
    expect(find.byKey(MomentCameraKeys.capturedPreview),findsOneWidget);
    await tester.tap(find.byKey(MomentCameraKeys.sendButton));
    await tester.pump();
    final sheet=tester.widget<MomentPublishSheet>(
        find.byType(MomentPublishSheet));
    expect(sheet.initialFilter,MomentFilter.cool);
    expect(sheet.photoBytes,orderedEquals(photo));
    expect(tester.takeException(),isNull);
  });

  testWidgets('camera tools stay scrollable on compact screens and text does not shoot',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home:MomentCameraScreen(
      enableCamera:false,
    )));
    await tester.pump();
    expect(find.byType(MomentPublishSheet),findsNothing);
    expect(find.byKey(MomentCameraKeys.toolsColumn),findsOneWidget);
    final rail=tester.widget<SingleChildScrollView>(
        find.byKey(MomentCameraKeys.toolsColumn));
    expect(rail.scrollDirection,Axis.vertical);
    await tester.tap(find.byKey(MomentCameraKeys.textButton));
    await tester.pump();
    expect(find.byKey(MomentCameraKeys.toolHint),findsOneWidget);
    expect(find.byKey(MomentCameraKeys.capturedPreview),findsNothing);
    expect(find.byType(MomentPublishSheet),findsNothing);
    expect(tester.takeException(),isNull);
  });

}
