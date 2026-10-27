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
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGMsW/KQgYGBiYGBgYGBAQAXgwH/fm0M2gAAAABJRU5ErkJggg=='));
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
    await tester.pumpAndSettle();
    expect(find.byKey(MomentCameraKeys.voiceConsent),findsOneWidget);
    expect(find.text('Record a Voice Moment?'),findsOneWidget);
    expect(find.text('Continue to Voice'),findsOneWidget);
    await tester.tap(find.text('Continue to Voice'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Hold to record moment'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('filters open over live preview without auto-capturing or publishing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo=Uint8List.fromList(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGMsW/KQgYGBiYGBgYGBAQAXgwH/fm0M2gAAAABJRU5ErkJggg=='));
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
    final selected=tester.widget<Container>(
      find.descendant(
        of:find.byKey(MomentCameraKeys.filter(MomentFilter.warm.name)),
        matching:find.byType(Container)).first);
    expect((selected.decoration as BoxDecoration).gradient,isNotNull);
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
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGMsW/KQgYGBiYGBgYGBAQAXgwH/fm0M2gAAAABJRU5ErkJggg=='));
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

  testWidgets('retake clears captured gallery image and restores camera tools',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo=Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGMsW/KQgYGBiYGBgYGBAQAXgwH/fm0M2gAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(MaterialApp(home:MomentCameraScreen(
      enableCamera:false,galleryPicker:() async=>photo,
    )));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.galleryButton));
    await tester.pumpAndSettle();
    expect(find.byKey(MomentCameraKeys.capturedPreview),findsOneWidget);
    expect(find.byKey(MomentCameraKeys.retakeButton),findsOneWidget);
    expect(find.byKey(MomentCameraKeys.galleryButton),findsNothing);
    await tester.tap(find.byKey(MomentCameraKeys.retakeButton));
    await tester.pumpAndSettle();
    expect(find.byKey(MomentCameraKeys.capturedPreview),findsNothing);
    expect(find.byKey(MomentCameraKeys.galleryButton),findsOneWidget);
    expect(find.byKey(MomentCameraKeys.retakeButton),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('graphic sticker stays in camera and can be repositioned',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo=Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGMsW/KQgYGBiYGBgYGBAQAXgwH/fm0M2gAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(MaterialApp(home:MomentCameraScreen(
      enableCamera:false,galleryPicker:()async=>photo,
    )));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.galleryButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MomentCameraKeys.stickersButton));
    await tester.pump();
    expect(find.byKey(MomentCameraKeys.stickerTray),findsOneWidget);
    expect(find.byType(BottomSheet),findsNothing);
    await tester.tap(find.byKey(const Key('moment_camera_sticker_choice_10084')));
    await tester.pump();
    expect(find.byKey(MomentCameraKeys.sticker('1')),findsOneWidget);
    expect(find.byKey(MomentCameraKeys.stickerTray),findsNothing);
    final before=tester.getCenter(find.byKey(MomentCameraKeys.sticker('1')));
    await tester.drag(find.byKey(MomentCameraKeys.sticker('1')),
      const Offset(35,70));
    await tester.pump();
    final after=tester.getCenter(find.byKey(MomentCameraKeys.sticker('1')));
    expect(after.dx,greaterThan(before.dx));
    expect(after.dy,greaterThan(before.dy));
    expect(tester.takeException(),isNull);
  });

  testWidgets('draw colors and undo are on the captured photo without a sheet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo=Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGMsW/KQgYGBiYGBgYGBAQAXgwH/fm0M2gAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(MaterialApp(home:MomentCameraScreen(
      enableCamera:false,galleryPicker:()async=>photo,
    )));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.galleryButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MomentCameraKeys.drawButton));
    await tester.pump();
    expect(find.byKey(MomentCameraKeys.drawPalette),findsOneWidget);
    await tester.tap(find.byKey(const Key('moment_camera_ink_color_2')));
    await tester.pump();
    await tester.dragFrom(const Offset(85,230),const Offset(90,60));
    await tester.pump();
    expect(find.byKey(MomentCameraKeys.photoInk),findsOneWidget);
    await tester.tap(find.byKey(const Key('moment_camera_draw_done')));
    await tester.pump();
    expect(find.byKey(MomentCameraKeys.drawPalette),findsNothing);
    expect(find.byKey(MomentCameraKeys.capturedPreview),findsOneWidget);
    expect(find.byType(BottomSheet),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('filter circle is centered on the vertical toolbar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home:MomentCameraScreen(
      enableCamera:false,
    )));
    await tester.pump();
    final filterX=tester.getCenter(find.byKey(MomentCameraKeys.filterButton)).dx;
    final railX=tester.getCenter(find.byKey(MomentCameraKeys.toolsColumn)).dx;
    expect(filterX,closeTo(railX,1));
    expect(tester.takeException(),isNull);
  });

  testWidgets('graphic stickers are included in exported photo bytes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source=Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGMsW/KQgYGBiYGBgYGBAQAXgwH/fm0M2gAAAABJRU5ErkJggg=='));
    Uint8List? exported;
    await tester.pumpWidget(MaterialApp(home:MomentCameraScreen(
      enableCamera:false,galleryPicker:()async=>source,
      onSendPressed:(bytes)=>exported=bytes,
    )));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.galleryButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MomentCameraKeys.stickersButton));
    await tester.pump();
    await tester.tap(find.byKey(const Key('moment_camera_sticker_choice_10084')));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.sendButton));
    await tester.pumpAndSettle();
    expect(exported,isNotNull);
    expect(exported!.take(8).toList(),<int>[
      137,80,78,71,13,10,26,10,
    ]);
    expect(exported!.length,greaterThan(source.length));
    expect(tester.takeException(),isNull);
  });

  testWidgets('voice recording consent can be declined without changing mode',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home:MomentCameraScreen(
      enableCamera:false,
    )));
    await tester.pump();
    await tester.tap(find.byKey(MomentCameraKeys.voiceMode));
    await tester.pumpAndSettle();
    expect(find.byKey(MomentCameraKeys.voiceConsent),findsOneWidget);
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.byKey(MomentCameraKeys.voiceConsent),findsNothing);
    expect(find.bySemanticsLabel('Capture moment'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

}
