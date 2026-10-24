import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/presentation/screens/moment_camera_screen.dart';

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

}
