import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:compress_video/compress_video.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_media_crypto.dart';
import '../../moments/data/orbit_camera_policy.dart';
import '../../moments/data/orbit_capture_inspection.dart';
import '../../moments/data/orbit_capture_temp_files.dart';
import 'orbit_media_outbox.dart';
import 'orbit_media_repository.dart';
import 'orbit_media_transfer_gate.dart';

/// M6 codec policy: client-side native encode before any server sees a byte.
/// The output is still device-local plaintext until sealed and immediately
/// removed; only the encrypted file is queued or sent over the network.
class OrbitPreparedVideo {
  const OrbitPreparedVideo({
    required this.file, required this.posterJpeg, required this.durationMs,
    required this.width, required this.height,
  });
  final File file;
  final Uint8List posterJpeg;
  final int durationMs, width, height;
}

abstract class OrbitVideoProcessor {
  Future<OrbitPreparedVideo> prepare(File input,
      {void Function(double progress)? onProgress});
}

class OrbitNativeVideoProcessor implements OrbitVideoProcessor {
  OrbitNativeVideoProcessor({CompressVideo? compressor})
    : _compressor=compressor??CompressVideo();
  final CompressVideo _compressor;
  static const maxDurationMs=60000;
  static const maxUncompressedBytes=500*1024*1024;

  @override
  Future<OrbitPreparedVideo> prepare(File input,
      {void Function(double progress)? onProgress}) =>
    _prepare(input,onProgress:onProgress,stripAudio:false);

  Future<OrbitPreparedVideo> prepareWithoutAudio(File input,
      {void Function(double progress)? onProgress}) =>
    _prepare(input,onProgress:onProgress,stripAudio:true);

  Future<OrbitPreparedVideo> prepareForNetwork(File input,
      {bool stripAudio=false,bool lowBandwidth=false,
       void Function(double progress)? onProgress}) =>
    _prepare(input,onProgress:onProgress,
      stripAudio:stripAudio,lowBandwidth:lowBandwidth);

  Future<OrbitPreparedVideo> _prepare(File input,
      {void Function(double progress)? onProgress,
       required bool stripAudio,bool lowBandwidth=false}) async {
    if(!await input.exists() || await input.length()>maxUncompressedBytes
        || await input.length()==0) {
      throw const FormatException('Video file exceeds the capture limits.');
    }
    final policy=OrbitCameraPolicy.current;
    final initial=await _compressor.getMediaInfo(input.path);
    if(initial.durationMs<=0 || initial.durationMs>policy.videoDuration) {
      throw const FormatException('Orbit supports video clips up to 60 seconds.');
    }
    // compress_video's never-larger guarantee may return the source even
    // when requested options were different. Always use an app-owned fresh
    // MP4 destination and independently inspect the final sanitized output.
    final scratch=OrbitCaptureTempFiles();
    final limit=policy.videoBitrate(lowBandwidth);
    final sourceRate=initial.videoBitrateBps?.toInt()??limit;
    final targets=<int>[
      min(limit,(max(1,sourceRate)*0.80).round()),
      min((limit*0.65).round(),(max(1,sourceRate)*0.50).round()),
      min((limit*0.40).round(),(max(1,sourceRate)*0.30).round()),
    ].map((n)=>max(64000,min(n,limit))).toList();
    Object? lastFailure;
    Future<OrbitPreparedVideo> checked(File candidate)async{
      final output=await scratch.allocate('mp4');
      try{
        // Copy media tracks into a clean container, retaining orientation,
        // never the source metadata. Mute means NO audio track.
        await OrbitCaptureInspection.sanitizeMp4(candidate,output,muted:stripAudio);
        if(!await output.exists()||await output.length()<1||
           await output.length()>OrbitMediaFormat.videoLimit){
          throw const FormatException('Prepared MP4 exceeds upload limits.');
        }
        final duration=await OrbitCaptureInspection.validate(output,kind:'video',
          policy:policy,muted:stripAudio,saver:lowBandwidth);
        final info=await _compressor.getMediaInfo(output.path);
        if(info.widthPx<1||info.heightPx<1||
           max(info.widthPx,info.heightPx)>policy.videoEdge){
          throw const FormatException('Prepared MP4 has invalid dimensions.');
        }
        final bytes=await _compressor.getThumbnail(output.path,
          positionMs:min(duration~/2,1500),quality:78,maxDimensionPx:320);
        final poster=OrbitMediaCrypto.preparePhoto(bytes).thumbnail;
        return OrbitPreparedVideo(file:output,posterJpeg:poster,
          durationMs:duration,width:info.widthPx,height:info.heightPx);
      }catch(_){
        try{await scratch.deleteCacheFile(output);}catch(_){}
        rethrow;
      }
    }
    for(var attempt=0;attempt<targets.length;attempt++){
      final destination=await scratch.allocate('mp4');
      File? candidate;
      try{
        final edge=attempt<2?policy.videoEdge:min(policy.videoEdge,960);
        final fps=attempt<2?policy.videoFps:min(policy.videoFps,24);
        final job=_compressor.compress(input.path,options:CompressOptions(
          preset:CompressPreset.p720,maxLongSidePx:edge,maxFps:fps,
          videoBitrateBps:targets[attempt],outputPath:destination.path,
          codec:VideoCodec.h264,
          audio:stripAudio?const AudioStrip():const AudioReencode(bitrateBps:96000,channels:2)));
        final progress=job.progress.listen((value){
          onProgress?.call((value/100).clamp(0.0,1.0));
        });
        late final CompressResult result;
        try{result=await job.result;}finally{await progress.cancel();}
        candidate=File(result.outputPath);
        // Used-original is NOT permission to upload raw bytes. A source
        // that is already compliant can be safely remuxed and independently
        // validated. Otherwise try the next lower encode target.
        final prepared=await checked(candidate);
        onProgress?.call(1);
        return prepared;
      }catch(error){lastFailure=error;}
      finally{
        for(final file in [destination,if(candidate!=null)candidate]){
          if(file.path!=input.path){
            try{await scratch.deleteCacheFile(file);}catch(_){}
          }
        }
      }
    }
    // Some devices report a compressor failure for already compatible
    // short clips. A clean native remux is allowed only if every original
    // codec, duration, size, track and bitrate check still passes.
    try{return await checked(input);}catch(error){lastFailure=error;}
    // Keep the original capture; the encrypted draft can be retried.
    throw FormatException('Video export could not meet the current capture policy.',
      lastFailure.runtimeType.toString());
  }

}

class OrbitStagedClip {
  const OrbitStagedClip({required this.mediaId, required this.verified,
    required this.privateGrantConfirmed});
  final String mediaId;
  final bool verified, privateGrantConfirmed;
  // A stored encrypted file is never a published Moment/message.
  bool get published => false;
}

/// No UI components. Existing camera controls remain responsible for capture;
/// later M7/M13 consumers must explicitly confirm Circle audience publishing.
class OrbitEncryptedClipStager {
  OrbitEncryptedClipStager({OrbitIdentityClient? identity,
    OrbitMediaCrypto? crypto, OrbitMediaRepository? media,
    OrbitMediaOutbox? outbox, OrbitVideoProcessor? processor,
    Future<Directory> Function()? temporaryDirectory,this.expectedOwner})
      : _identity=identity??OrbitIdentityClient.instance,
        _crypto=crypto??OrbitMediaCrypto(),
        _media=media??OrbitMediaRepository(identity:identity),
        _outbox=outbox??OrbitMediaOutbox(),
        _processor=processor??OrbitNativeVideoProcessor(),
        _temp=temporaryDirectory??getTemporaryDirectory;
  final OrbitIdentityClient _identity;
  final String? expectedOwner;
  final OrbitMediaCrypto _crypto;
  final OrbitMediaRepository _media;
  final OrbitMediaOutbox _outbox;
  final OrbitVideoProcessor _processor;
  final Future<Directory> Function() _temp;

  Future<OrbitStagedClip> stageVideo(File original,
      {void Function(double progress)? onProgress,
       Future<void> Function(OrbitSealedMedia original, OrbitSealedMedia poster,
         String mediaId)? onReadyForAudience,
       Future<void> Function(String originalTransfer)? onQueued,
       bool muteAudio=false,bool lowBandwidth=false}) async {
    return OrbitMediaTransferGate.run(() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null||(expectedOwner!=null&&owner!=expectedOwner))throw OrbitIdentityException('Please sign in to the original capture account.',401);
    final device=await _identity.trustedMediaDevice();
    final prepared=await (_processor is OrbitNativeVideoProcessor
      ? _processor.prepareForNetwork(original,
          stripAudio:muteAudio,lowBandwidth:lowBandwidth,
          onProgress:onProgress)
      : (muteAudio||lowBandwidth)
        ? throw StateError('Selected video processor cannot enforce export options.')
        : _processor.prepare(original,onProgress:onProgress));
    try {
    final root=Directory((await _temp()).path+'/orbit-m6-transcode');
    await root.create(recursive:true);
    final videoId=const Uuid().v4(),posterId=const Uuid().v4();
    final video=await _crypto.sealFile(prepared.file,
      destination:File(root.path+'/'+videoId+'.cipher'),
      ownerId:owner,transferId:videoId,purpose:'moment',
      maxInputBytes:OrbitMediaFormat.videoLimit);
    final poster=await _crypto.sealBytes(prepared.posterJpeg,
      destination:File(root.path+'/'+posterId+'.cipher'),
      ownerId:owner,transferId:posterId,purpose:'moment',variant:'poster');
    if(await _identity.currentLocalSocialOwner()!=owner){await video.file.delete();await poster.file.delete();throw StateError('Capture account changed.');}
    final first=await _outbox.enqueue(video,kind:'video',
      mime:'video/mp4',width:prepared.width,height:prepared.height,
      durationMs:prepared.durationMs);
    var second=await _outbox.enqueue(poster,kind:'image',
      mime:'image/jpeg',parentTransferId:videoId);
    if(onQueued!=null)await onQueued(videoId);
    try {
      await video.file.delete();
      await poster.file.delete();
      final receipt=await _media.upload(await _outbox.restore(first),
        kind:'video',mime:'video/mp4',width:prepared.width,
        height:prepared.height,durationMs:prepared.durationMs,
        onProgress:(p)=>onProgress?.call(0.35+0.55*p));
      if(!receipt.ready)throw StateError('Video verification pending.');
      second=await _outbox.bindVariantParent(second,receipt.mediaId);
      final frame=await _media.upload(await _outbox.restore(second),
        kind:'image',mime:'image/jpeg',parentMediaId:receipt.mediaId,
        onProgress:(p)=>onProgress?.call(0.90+0.08*p));
      if(!frame.ready)throw StateError('Poster verification pending.');
      final grants=await _media.createGrants(receipt.mediaId,
        audience:'only_me',recipients:const [],
        idempotencyKey:videoId,
        keyEnvelopes:await _outbox.grantEnvelopeOnce(owner,videoId,() async => [
          {'device_id':device.id,'variant':'original','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(video,device.publicKey)},
          {'device_id':device.id,'variant':'poster','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(poster,device.publicKey)},
        ]));
      if(grants.isEmpty)throw StateError('Device grants not confirmed.');
      if(onReadyForAudience!=null){
        await onReadyForAudience(video,poster,receipt.mediaId);
      }
      await _outbox.discard(first);
      await _outbox.discard(second);
      onProgress?.call(1);
      return OrbitStagedClip(mediaId:receipt.mediaId,
        verified:true,privateGrantConfirmed:true);
    } catch (_) {
      // Ciphertext-only drafts remain in the offline outbox for explicit retry.
      rethrow;
    }
    } finally {
      // This native transcode is plaintext until its encrypted queue copy is
      // durably saved. Clean it up even when sealing or enqueue fails before
      // the upload/catch block starts. Never delete the user's gallery source.
      if(prepared.file.path!=original.path){
        try {
          if(await prepared.file.exists())await prepared.file.delete();
        } catch (_) { /* Keep original failure; OS temporary cleanup is best effort. */ }
      }
    }
    });
  }

  /// Voice recordings are already AAC/MP4/OGG from the existing capture
  /// module. No separate voice record popup or codec fallback is added here.
  static Uint8List _voiceWaveformJpeg(List<double> levels) {
    if(levels.length>500)throw const FormatException('Too many voice samples.');
    final bitmap=img.Image(width:320,height:96);
    for(var y=0;y<96;y++){
      for(var x=0;x<320;x++)bitmap.setPixelRgb(x,y,250,250,250);
    }
    final peaks=levels.isEmpty?const [0.02]:levels;
    for(var i=0;i<32;i++){
      final level=peaks[(i*peaks.length/32).floor()
        .clamp(0,peaks.length-1).toInt()].clamp(0.01,1.0);
      final h=(level*72).round().clamp(2,72).toInt();
      final x=8+i*10;
      img.drawLine(bitmap,x1:x,y1:48-h~/2,x2:x,y2:48+h~/2,
        color:img.ColorRgb8(79,55,140),thickness:4);
    }
    return Uint8List.fromList(img.encodeJpg(bitmap,quality:78));
  }

  Future<OrbitStagedClip> stageAudio(File encoded,{
    required String mime,required int durationMs,
    String purpose='message',
    List<double> waveformLevels=const [],
    Future<void> Function(OrbitSealedMedia original,
      OrbitSealedMedia? waveform,String mediaId)? onReadyForAudience,
    Future<void> Function(String originalTransfer)? onQueued,
    void Function(double progress)? onProgress,
  }) async {
    return OrbitMediaTransferGate.run(() async {
      if(!['audio/mp4','audio/aac','audio/ogg'].contains(mime) ||
          durationMs<=0 || durationMs>60000){
        throw const FormatException('Unsupported encoded voice clip.');
      }
      if(!['message','moment'].contains(purpose)){
        throw ArgumentError('Invalid audio purpose.');
      }
      if(purpose=='moment'){
        durationMs=await OrbitCaptureInspection.validate(encoded,kind:'audio',policy:OrbitCameraPolicy.current);
      }
      final owner=await _identity.currentLocalSocialOwner();
      if(owner==null||(expectedOwner!=null&&owner!=expectedOwner))throw OrbitIdentityException('Please sign in to the original capture account.',401);
      final device=await _identity.trustedMediaDevice();
      final temp=await _temp();
      final id=const Uuid().v4();
      final sealed=await _crypto.sealFile(encoded,
        destination:File(temp.path+'/'+id+'.voice.cipher'),
        ownerId:owner,transferId:id,purpose:purpose,
        maxInputBytes:OrbitMediaFormat.audioLimit);
      if(await _identity.currentLocalSocialOwner()!=owner){await sealed.file.delete();throw StateError('Capture account changed.');}
      final draft=await _outbox.enqueue(sealed,kind:'audio',mime:mime,
        durationMs:durationMs);
      OrbitSealedMedia? waveform;
      OrbitQueuedMedia? waveformDraft;
      if(purpose=='moment'){
        final waveId=const Uuid().v4();
        waveform=await _crypto.sealBytes(_voiceWaveformJpeg(waveformLevels),
          destination:File(temp.path+'/'+waveId+'.wave.cipher'),
          ownerId:owner,transferId:waveId,purpose:'moment',variant:'waveform');
        waveformDraft=await _outbox.enqueue(waveform,kind:'image',
          mime:'image/jpeg',parentTransferId:id,width:320,height:96);
      }
      if(onQueued!=null)await onQueued(id);
      try{
        await sealed.file.delete();
        if(waveform!=null)await waveform.file.delete();
        final uploaded=await _media.upload(await _outbox.restore(draft),
          kind:'audio',mime:mime,durationMs:durationMs,
          onProgress:(value)=>onProgress?.call(value*0.80));
        if(!uploaded.ready)throw StateError('Voice upload still verifying.');
        if(waveformDraft!=null){
          waveformDraft=await _outbox.bindVariantParent(
            waveformDraft,uploaded.mediaId);
          final derivative=await _media.upload(
            await _outbox.restore(waveformDraft),
            kind:'image',mime:'image/jpeg',
            parentMediaId:uploaded.mediaId,
            onProgress:(value)=>onProgress?.call(0.80+value*0.18));
          if(!derivative.ready){
            throw StateError('Voice waveform verification pending.');
          }
        }
        final envelopes=await _outbox.grantEnvelopeOnce(owner,id,() async {
          final keys=<Map<String,Object?>>[
            {'device_id':device.id,'variant':'original','key_version':'v1',
              'algorithm':OrbitMediaFormat.envelopeAlgorithm,
              'wrapped_key_ciphertext':await _crypto.wrapKey(
                sealed,device.publicKey)},
          ];
          if(waveform!=null){
            keys.add({
              'device_id':device.id,'variant':'waveform','key_version':'v1',
              'algorithm':OrbitMediaFormat.envelopeAlgorithm,
              'wrapped_key_ciphertext':await _crypto.wrapKey(
                waveform,device.publicKey),
            });
          }
          return keys;
        });
        final grants=await _media.createGrants(uploaded.mediaId,
          audience:'only_me',recipients:const [],
          idempotencyKey:id,keyEnvelopes:envelopes);
        if(grants.isEmpty)throw StateError('Voice key grant not confirmed.');
        if(onReadyForAudience!=null){
          await onReadyForAudience(sealed,waveform,uploaded.mediaId);
        }
        if(waveformDraft!=null)await _outbox.discard(waveformDraft);
        await _outbox.discard(draft);
        onProgress?.call(1);
        return OrbitStagedClip(mediaId:uploaded.mediaId,
          verified:true,privateGrantConfirmed:true);
      }catch(_){
        // Failed uploads retain only encrypted private outbox artifacts.
        rethrow;
      }
    });
  }

}
