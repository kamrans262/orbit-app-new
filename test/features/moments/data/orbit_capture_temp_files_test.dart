import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/data/orbit_capture_temp_files.dart';

void main(){
  test('Interrupted cleanup only removes owned scratch and known legacy files',() async{
    final root=await Directory.systemTemp.createTemp('orbit-m23-');
    final outside=await Directory.systemTemp.createTemp('orbit-original-');
    try{
      final files=OrbitCaptureTempFiles(temporaryDirectory:()async=>root);
      final source=File(outside.path+'/original.mp4');await source.writeAsBytes([1,2,3]);
      final copied=await files.copyClip(source,extension:'mp4',maxBytes:5);
      expect(await copied.readAsBytes(),[1,2,3]);
      await files.deleteCacheFile(source);
      expect(await source.exists(),true);
      await expectLater(files.copyClip(source,extension:'mp4',maxBytes:2),throwsFormatException);
      final other=File(root.path+'/unrelated.mp4');await other.writeAsBytes([4]);
      final legacy=File(root.path+'/orbit-m7-voice-123.m4a');await legacy.writeAsBytes([4]);
      await files.sweepInterrupted();
      expect(await copied.exists(),false);expect(await legacy.exists(),false);
      expect(await other.exists(),true);expect(await source.exists(),true);
    }finally{await root.delete(recursive:true);await outside.delete(recursive:true);}
  });
}
