import 'dart:io';
import 'package:flutter/services.dart';
import 'orbit_camera_policy.dart';

class OrbitVideoPreparationFailure extends FormatException {
  const OrbitVideoPreparationFailure(this.stage,this.reason)
    : super('Video preparation failed.');
  final String stage,reason;
}

class OrbitCapturePolicyFailure extends FormatException {
  const OrbitCapturePolicyFailure(this.code,String message):super(message);
  final String code;
}

class OrbitValidatedVideo {
  const OrbitValidatedVideo(this.durationMs,this.width,this.height);
  final int durationMs,width,height;
}

abstract final class OrbitCaptureInspection {
  static const channel=MethodChannel('orbit/capture_inspection');
  /// Rebuild a private MP4 container without source metadata. This does not
  /// certify the codec: the result must still pass validate before encryption.
  static Future<void> sanitizeMp4(File input,File output,{required bool muted})async{
    await channel.invokeMethod<void>('sanitizeMp4',{'path':input.path,'output':output.path,'muted':muted});
  }
  static Future<int> validate(File file,{required String kind,
    required OrbitCameraPolicy policy,bool muted=false,bool saver=false}) async{
    final raw=await inspect(file);
    return validateMetadata(raw,kind:kind,policy:policy,muted:muted,saver:saver);
  }
  static Future<Map<String,dynamic>> inspect(File file)async{
    final raw=await channel.invokeMapMethod<String,dynamic>('inspect',{'path':file.path});
    if(raw==null)throw const OrbitCapturePolicyFailure('missing_metadata','Capture metadata unavailable.');
    return raw;
  }
  static OrbitValidatedVideo validateVideoMetadata(Map<String,dynamic> raw,{
    required OrbitCameraPolicy policy,bool muted=false,bool saver=false}){
    final duration=validateMetadata(raw,kind:'video',policy:policy,muted:muted,saver:saver);
    final w=raw['width'] as int,h=raw['height'] as int;
    final rotation=raw['rotation_degrees'];
    return rotation==90||rotation==270
      ?OrbitValidatedVideo(duration,h,w):OrbitValidatedVideo(duration,w,h);
  }
  static int validateMetadata(Map<String,dynamic> raw,{required String kind,
    required OrbitCameraPolicy policy,bool muted=false,bool saver=false}){
    final duration=raw['duration_ms'];
    if(duration is! int||raw['location_metadata']!=false||
       raw['video_tracks'] is! int||raw['audio_tracks'] is! int){
      throw const OrbitCapturePolicyFailure('metadata_or_location','Capture metadata unavailable or contains location.');
    }
    try{policy.requireDuration(kind,duration);}
    on FormatException{throw const OrbitCapturePolicyFailure('duration','Recording exceeds current capture policy.');}
    final audio=raw['audio_tracks'] as int,video=raw['video_tracks'] as int;
    if(audio<0||audio>1||video<0||video>1)throw const OrbitCapturePolicyFailure('track_count','Unsupported capture tracks.');
    if(kind=='audio'){
      final bitrate=raw['audio_bps'];
      if(video!=0||audio!=1||raw['audio_aac_lc']!=true||
        raw['audio_channels']!=1||bitrate is! num||!bitrate.isFinite||bitrate<=0||bitrate>80000){
        throw const OrbitCapturePolicyFailure('voice_format','Voice must be AAC-LC mono with bounded bitrate.');
      }
    }else if(kind=='video'){
      if(video!=1||(muted&&audio!=0)||(audio==1&&raw['audio_aac_lc']!=true)){
        throw const OrbitCapturePolicyFailure('video_audio_tracks','Video or audio track does not meet export policy.');
      }
      final w=raw['width'],h=raw['height'],fps=raw['fps'],bps=raw['video_bps'];
      if(raw['video_h264']!=true){
        throw const OrbitCapturePolicyFailure('video_codec','Video encoding does not meet export policy.');
      }
      if(w is! int||h is! int||w<1||h<1||w>policy.videoEdge||h>policy.videoEdge){
        throw const OrbitCapturePolicyFailure('video_dimensions','Video encoding does not meet export policy.');
      }
      if(fps is! num||!fps.isFinite||fps<=0||fps>policy.videoFps+0.5){
        throw const OrbitCapturePolicyFailure('video_fps','Video encoding does not meet export policy.');
      }
      if(bps is! num||!bps.isFinite||bps<=0||bps>policy.videoBitrate(saver)*1.125){
        throw const OrbitCapturePolicyFailure('video_bitrate','Video encoding does not meet export policy.');
      }
    }else{throw const FormatException('Unsupported capture kind.');}
    return duration;
  }
}
