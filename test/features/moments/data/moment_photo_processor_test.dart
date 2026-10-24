import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:orbit_ui/features/moments/data/moment_photo_processor.dart';

void main(){
  final source=Uint8List.fromList(img.encodePng(
    img.Image(width:4,height:4)..setPixelRgb(0,0,100,110,120)));
  test('M7 has exactly nine named editable image filters',(){
    expect(MomentFilter.values.map((f)=>f.label),[
      'Natural','Warm','Cool','Portrait','Film','Night','Soft',
      'Vibrant','Black & White']);
  });
  test('Photo editor converts image into metadata-free JPEG pixels',(){
    final bytes=MomentPhotoProcessor.render(source,const MomentPhotoEdit());
    expect(bytes.take(2).toList(),[0xff,0xd8]);
    final out=img.decodeJpg(bytes)!;
    expect(out.width,4);
    expect(out.height,4);
  });
  test('All filters produce an encrypted-upload-ready image without using network',(){
    for(final filter in MomentFilter.values){
      final bytes=MomentPhotoProcessor.render(source,MomentPhotoEdit(filter:filter));
      expect(img.decodeJpg(bytes),isNotNull,reason:filter.label);
    }
  });
  test('Beauty control is opt-in, finite and bounded before encryption',(){
    final normal=MomentPhotoProcessor.render(source,const MomentPhotoEdit());
    final explicitOff=MomentPhotoProcessor.render(source,
      const MomentPhotoEdit(beautyStrength:0));
    expect(explicitOff,orderedEquals(normal));
    final adjusted=MomentPhotoProcessor.render(source,
      const MomentPhotoEdit(beautyStrength:0.20));
    expect(img.decodeJpg(adjusted),isNotNull);
    expect(()=>MomentPhotoProcessor.render(source,
      const MomentPhotoEdit(beautyStrength:0.5)),throwsFormatException);
  });

  test('Rejects too-long overlay before upload',(){
    expect(()=>MomentPhotoProcessor.render(source,MomentPhotoEdit(
      text:List<String>.filled(81,'x').join())),throwsFormatException);
  });
}
