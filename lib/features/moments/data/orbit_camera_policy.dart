import '../../config/data/orbit_public_config_runtime.dart';

/// Public hints are not authorization. Missing/malformed snapshots retain
/// compatible hard limits; server validation remains authoritative.
class OrbitCameraPolicy {
  const OrbitCameraPolicy({this.revision=0,this.enhanced=false,
    this.photoEdge=1440,this.saverEdge=1080,this.jpegQuality=80,
    this.videoDuration=60000,this.videoEdge=1280,this.videoFps=30,
    this.videoBps=4000000,this.saverVideoBps=2000000,this.voiceDuration=60000});
  final int revision,photoEdge,saverEdge,jpegQuality,videoDuration,videoEdge,
    videoFps,videoBps,saverVideoBps,voiceDuration;
  final bool enhanced;
  static OrbitCameraPolicy get current=>fromHints(
    OrbitPublicConfigRuntime.instance.snapshot?.config['camera.operations']);
  static OrbitCameraPolicy fromHints(Object? raw){
    if(raw is! Map||raw['schema_version']!=1||
       raw['revision'] is! int||(raw['revision'] as int)<1||
       raw['enhancements_enabled'] is! bool)return const OrbitCameraPolicy();
    int bounded(String key,int min,int max){
      final v=raw[key];
      if(v is! int||v<min||v>max)throw const FormatException('Invalid capture policy.');
      return v;
    }
    try{
      final p=OrbitCameraPolicy(revision:raw['revision'] as int,
        enhanced:raw['enhancements_enabled'] as bool,
        photoEdge:bounded('photo_long_edge_px',720,1440),
        saverEdge:bounded('photo_data_saver_long_edge_px',480,1080),
        jpegQuality:bounded('photo_jpeg_quality',60,80),
        videoDuration:bounded('video_duration_ms',1000,60000),
        videoEdge:bounded('video_max_long_edge_px',480,1280),
        videoFps:bounded('video_max_fps',15,30),
        videoBps:bounded('video_target_bps',500000,4000000),
        saverVideoBps:bounded('video_data_saver_target_bps',250000,2000000),
        voiceDuration:bounded('voice_duration_ms',1000,60000));
      if(p.saverEdge>p.photoEdge||p.saverVideoBps>p.videoBps||
         raw['voice_codec']!='AAC-LC'||raw['voice_channels']!=1||
         raw['voice_target_bps']!=64000)throw const FormatException('Invalid profile.');
      return p;
    }catch(_){return const OrbitCameraPolicy();}
  }
  int photoLimit(bool saver)=>saver?saverEdge:photoEdge;
  int videoBitrate(bool saver)=>saver?saverVideoBps:videoBps;
  void requireDuration(String kind,int milliseconds){
    if(milliseconds<1||milliseconds>(kind=='audio'?voiceDuration:videoDuration)){
      throw const FormatException('Recording exceeds current capture policy.');
    }
  }
}
