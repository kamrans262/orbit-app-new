import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:compress_video/compress_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_media_crypto.dart';
import 'orbit_media_outbox.dart';
import 'orbit_media_repository.dart';

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
      {void Function(double progress)? onProgress}) async {
    if(!await input.exists() || await input.length()>maxUncompressedBytes
        || await input.length()==0) {
      throw const FormatException('Video file exceeds the capture limits.');
    }
    final initial=await _compressor.getMediaInfo(input.path);
    if(initial.durationMs<=0 || initial.durationMs>maxDurationMs) {
      throw const FormatException('Orbit supports video clips up to 60 seconds.');
    }
    // Native Media3/AVFoundation encoding; strips original EXIF/GPS metadata
    // and makes a bounded MP4 before per-part authenticated encryption.
    final job=_compressor.compress(input.path,
      options:const CompressOptions(preset:CompressPreset.p720));
    final progress=job.progress.listen((value) {
      onProgress?.call((value/100).clamp(0.0,1.0));
    });
    late final CompressResult result;
    try {
      result=await job.result;
    } finally {
      await progress.cancel();
    }
    final path=result.outputPath;
    final output=File(path);
    if(!await output.exists() ||
       await output.length()<1 ||
       await output.length()>OrbitMediaFormat.videoLimit) {
      throw const FormatException('Compressed video exceeds upload limits.');
    }
    final info=await _compressor.getMediaInfo(output.path);
    if(info.durationMs<=0 || info.durationMs>maxDurationMs ||
        info.widthPx<=0 || info.heightPx<=0) {
      throw const FormatException('Compressed video metadata is invalid.');
    }
    final bytes=await _compressor.getThumbnail(output.path,
      positionMs:min(info.durationMs ~/ 2,1500), quality:78,
      maxDimensionPx:320);
    final poster=OrbitMediaCrypto.preparePhoto(bytes).thumbnail;
    return OrbitPreparedVideo(file:output,posterJpeg:poster,
      durationMs:info.durationMs,width:info.widthPx,height:info.heightPx);
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
    Future<Directory> Function()? temporaryDirectory})
      : _identity=identity??OrbitIdentityClient.instance,
        _crypto=crypto??OrbitMediaCrypto(),
        _media=media??OrbitMediaRepository(identity:identity),
        _outbox=outbox??OrbitMediaOutbox(),
        _processor=processor??OrbitNativeVideoProcessor(),
        _temp=temporaryDirectory??getTemporaryDirectory;
  final OrbitIdentityClient _identity;
  final OrbitMediaCrypto _crypto;
  final OrbitMediaRepository _media;
  final OrbitMediaOutbox _outbox;
  final OrbitVideoProcessor _processor;
  final Future<Directory> Function() _temp;

  Future<OrbitStagedClip> stageVideo(File original,
      {void Function(double progress)? onProgress}) async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)throw OrbitIdentityException('Please sign in.',401);
    final device=await _identity.trustedMediaDevice();
    final prepared=await _processor.prepare(original,
      onProgress:(p)=>onProgress?.call(p*0.35));
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
    final first=await _outbox.enqueue(video,kind:'video',
      mime:'video/mp4',width:prepared.width,height:prepared.height,
      durationMs:prepared.durationMs);
    var second=await _outbox.enqueue(poster,kind:'image',
      mime:'image/jpeg');
    try {
      if(await prepared.file.exists() &&
          prepared.file.path!=original.path)await prepared.file.delete();
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
        keyEnvelopes:[
          {'device_id':device.id,'variant':'original','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(video,device.publicKey)},
          {'device_id':device.id,'variant':'poster','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(poster,device.publicKey)},
        ]);
      if(grants.isEmpty)throw StateError('Device grants not confirmed.');
      await _outbox.discard(first);
      await _outbox.discard(second);
      onProgress?.call(1);
      return OrbitStagedClip(mediaId:receipt.mediaId,
        verified:true,privateGrantConfirmed:true);
    } catch (_) {
      // Ciphertext-only drafts remain in the offline outbox for explicit retry.
      rethrow;
    }
  }

  /// Voice recordings are already AAC/MP4/OGG from the existing capture
  /// module. No separate voice record popup or codec fallback is added here.
  Future<OrbitStagedClip> stageAudio(File encoded,{
    required String mime, required int durationMs,
    void Function(double progress)? onProgress,
  }) async {
    if(!['audio/mp4','audio/aac','audio/ogg'].contains(mime) ||
       durationMs<=0 || durationMs>60000) {
      throw const FormatException('Unsupported encoded voice clip.');
    }
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)throw OrbitIdentityException('Please sign in.',401);
    final device=await _identity.trustedMediaDevice();
    final temp=await _temp(); final id=const Uuid().v4();
    final sealed=await _crypto.sealFile(encoded,
      destination:File(temp.path+'/'+id+'.voice.cipher'),ownerId:owner,
      transferId:id,purpose:'message',
      maxInputBytes:OrbitMediaFormat.audioLimit);
    final draft=await _outbox.enqueue(sealed,kind:'audio',mime:mime,
      durationMs:durationMs);
    try {
      await sealed.file.delete();
      final uploaded=await _media.upload(await _outbox.restore(draft),
        kind:'audio',mime:mime,durationMs:durationMs,onProgress:onProgress);
      if(!uploaded.ready)throw StateError('Voice upload is still verifying.');
      final grants=await _media.createGrants(uploaded.mediaId,
        audience:'only_me',recipients:const [],
        idempotencyKey:id,keyEnvelopes:[
          {'device_id':device.id,'variant':'original','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(sealed,device.publicKey)},
        ]);
      if(grants.isEmpty)throw StateError('Voice key grant not confirmed.');
      await _outbox.discard(draft);
      return OrbitStagedClip(mediaId:uploaded.mediaId,
          verified:true,privateGrantConfirmed:true);
    } catch (_) { rethrow; }
  }
}
