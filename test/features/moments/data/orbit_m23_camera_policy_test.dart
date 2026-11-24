import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:orbit_ui/features/moments/data/orbit_camera_policy.dart';
import 'package:orbit_ui/features/moments/data/orbit_capture_inspection.dart';
import 'package:orbit_ui/features/moments/data/moment_photo_processor.dart';
import 'package:orbit_ui/features/media/data/orbit_media_crypto.dart';

Map<String,Object> hints()=>{'schema_version':1,'revision':4,'enhancements_enabled':true,
  'photo_long_edge_px':1200,'photo_data_saver_long_edge_px':720,'photo_jpeg_quality':70,
  'video_duration_ms':20000,'video_max_long_edge_px':960,'video_max_fps':24,
  'video_target_bps':3000000,'video_data_saver_target_bps':1000000,
  'voice_duration_ms':15000,'voice_codec':'AAC-LC','voice_channels':1,'voice_target_bps':64000};
void main(){
  test('versioned bounded backend policy consumes literal key values',(){
    final p=OrbitCameraPolicy.fromHints(hints());
    expect(p.revision,4);expect(p.enhanced,true);expect(p.photoLimit(true),720);
    expect(p.videoBitrate(true),1000000);
    expect(()=>p.requireDuration('video',20001),throwsFormatException);
    expect(()=>p.requireDuration('audio',15001),throwsFormatException);
  });
  test('malformed or cross-profile hints fail safely to baseline',(){
    for(final override in [{'schema_version':2},{'photo_long_edge_px':100000},
      {'photo_data_saver_long_edge_px':1081},{'voice_channels':2},{'revision':0}]){
      final p=OrbitCameraPolicy.fromHints({...hints(),...override});
      expect(p.revision,0);expect(p.enhanced,false);expect(p.photoEdge,1440);
    }
  });
  test('native metadata rejects unknown codecs, location, extra tracks and muted audio',(){
    final p=OrbitCameraPolicy.fromHints(hints());
    final meta=<String,dynamic>{'duration_ms':10000,'location_metadata':false,
      'video_tracks':1,'audio_tracks':0,'video_h264':true,'width':960,'height':540,
      'fps':24.0,'video_bps':950000};
    expect(OrbitCaptureInspection.validateMetadata(meta,kind:'video',policy:p,muted:true,saver:true),10000);
    for(final invalid in [{'location_metadata':true},{'audio_tracks':1},{'video_h264':false},
      {'fps':null},{'video_bps':2000000},{'width':961}]){
      expect(()=>OrbitCaptureInspection.validateMetadata({...meta,...invalid},kind:'video',policy:p,muted:true,saver:true),throwsFormatException);
    }
    final voice=<String,dynamic>{'duration_ms':1000,'location_metadata':false,'video_tracks':0,
      'audio_tracks':1,'audio_aac_lc':true,'audio_channels':1,'audio_bps':64000};
    expect(OrbitCaptureInspection.validateMetadata(voice,kind:'audio',policy:p),1000);
    expect(()=>OrbitCaptureInspection.validateMetadata({...voice,'audio_channels':2},kind:'audio',policy:p),throwsFormatException);
  });
  test('photo export and independent portrait thumbnail follow dynamic limits',(){
    final source=Uint8List.fromList(img.encodePng(img.Image(width:600,height:1200)));
    final photo=OrbitMediaCrypto.preparePhoto(source,maxLongSide:720,jpegQuality:70);
    expect(photo.height,720);expect(photo.width,360);
    expect(img.decodeJpg(photo.thumbnail)!.height,320);
    final rendered=MomentPhotoProcessor.render(source,const MomentPhotoEdit(maxLongSide:720,jpegQuality:70));
    expect(img.decodeJpg(rendered)!.height,720);
  });
}
