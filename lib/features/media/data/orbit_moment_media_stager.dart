import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_media_crypto.dart';
import 'orbit_media_outbox.dart';
import 'orbit_media_repository.dart';
import 'orbit_media_transfer_gate.dart';

/// This is *stored encrypted media*, not an M7 Moment publication receipt.
/// The current Orbit Moment publishing sheet must remain in its preview-only
/// state until an M7 API commits an actual Moment record with consent.
class OrbitStagedPhoto {
  const OrbitStagedPhoto({required this.mediaId,
      required this.thumbnailVerified, required this.privateGrantConfirmed});
  final String mediaId;
  final bool thumbnailVerified, privateGrantConfirmed;
  bool get isPublishedMoment => false;
}

/// Reuses the existing identity client. No new snackbar, dialog, progress
/// widget, camera route, or UI styling is created here.
class OrbitMomentMediaStager {
  OrbitMomentMediaStager({
    OrbitIdentityClient? identity,
    OrbitMediaCrypto? crypto,
    OrbitMediaRepository? repository,
    OrbitMediaOutbox? outbox,
    Future<Directory> Function()? temporaryDirectory,
  }) : _identity=identity??OrbitIdentityClient.instance,
       _crypto=crypto??OrbitMediaCrypto(),
       _repo=repository??OrbitMediaRepository(identity:identity),
       _outbox=outbox??OrbitMediaOutbox(),
       _directory=temporaryDirectory??getTemporaryDirectory;
  final OrbitIdentityClient _identity;
  final OrbitMediaCrypto _crypto;
  final OrbitMediaRepository _repo;
  final OrbitMediaOutbox _outbox;
  final Future<Directory> Function() _directory;

  /// The original and thumbnail have independent random keys and nonces.
  /// Both ciphertext files are placed in an account-bound offline outbox
  /// *before* the first network operation. On failures neither is claimed as
  /// published; the caller can retry the secure outbox.
  Future<OrbitStagedPhoto> stagePhoto(Uint8List captured,
      {void Function(double fraction)? onProgress,
       Future<void> Function(OrbitSealedMedia original, OrbitSealedMedia thumbnail,
         String mediaId)? onReadyForAudience,
       Future<void> Function(String originalTransfer)? onQueued}) async {
    return OrbitMediaTransferGate.run(() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)throw OrbitIdentityException('Please sign in first.',401);
    final device=await _identity.trustedMediaDevice();
    final prepared=await compute(OrbitMediaCrypto.preparePhoto,captured);
    final tmp=await _directory();
    final root=Directory(tmp.path+'/orbit-media-preparing');
    await root.create(recursive:true);
    final originalId=const Uuid().v4();
    final thumbnailId=const Uuid().v4();
    final original=await _crypto.sealBytes(prepared.jpeg,
      destination:File(root.path+'/'+originalId+'.cipher'),
      ownerId:owner,transferId:originalId,purpose:'moment');
    final thumb=await _crypto.sealBytes(prepared.thumbnail,
      destination:File(root.path+'/'+thumbnailId+'.cipher'),
      ownerId:owner,transferId:thumbnailId,purpose:'moment',
      variant:'thumbnail');
    final originalDraft=await _outbox.enqueue(original,kind:'image',
      mime:'image/jpeg',width:prepared.width,height:prepared.height);
    var thumbDraft=await _outbox.enqueue(thumb,kind:'image',
      mime:'image/jpeg',parentTransferId:originalId,width:320,
      height:(prepared.height*320/prepared.width).round());
    if(onQueued!=null)await onQueued(originalId);
    try {
      if(await original.file.exists())await original.file.delete();
      if(await thumb.file.exists())await thumb.file.delete();
      final readyOriginal=await _repo.upload(
          await _outbox.restore(originalDraft),
          kind:'image',mime:'image/jpeg',width:prepared.width,
          height:prepared.height,
          onProgress:(p)=>onProgress?.call(p*0.78));
      if(!readyOriginal.ready) {
        throw StateError('Encrypted upload is still verifying.');
      }
      thumbDraft=await _outbox.bindVariantParent(
          thumbDraft,readyOriginal.mediaId);
      final readyThumb=await _repo.upload(
          await _outbox.restore(thumbDraft),
          kind:'image',mime:'image/jpeg',parentMediaId:readyOriginal.mediaId,
          onProgress:(p)=>onProgress?.call(0.78+p*0.15));
      if(!readyThumb.ready) {
        throw StateError('Encrypted thumbnail is still verifying.');
      }
      // Save only a self-device envelope. Circle/friend delivery requires the
      // M7 consent and recipient-key flow; do not silently over-share.
      final grantIds=await _repo.createGrants(readyOriginal.mediaId,
        audience:'only_me',recipients:const [],
        idempotencyKey:originalId,
        keyEnvelopes:await _outbox.grantEnvelopeOnce(owner,originalId,() async => [
          {'device_id':device.id,'variant':'original','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(original,device.publicKey)},
          {'device_id':device.id,'variant':'thumbnail','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(thumb,device.publicKey)},
        ]));
      if(grantIds.isEmpty)throw StateError('Private media grant not confirmed.');
      // M7 creates real recipient envelopes and publishes while ephemeral
      // content keys are still available. Never discard on failed publish.
      if(onReadyForAudience!=null) {
        await onReadyForAudience(original,thumb,readyOriginal.mediaId);
      }
      onProgress?.call(1);
      await _outbox.discard(originalDraft);
      await _outbox.discard(thumbDraft);
      return OrbitStagedPhoto(mediaId:readyOriginal.mediaId,
        thumbnailVerified:true,privateGrantConfirmed:true);
    } catch (_) {
      // The outbox retains ciphertext and OS-backed keys for explicit retry.
      rethrow;
    }
    });
  }

  /// Resume originals first, then matching thumbnails and private grants.
  /// Uploading bytes is never equivalent to publishing an M7 Moment.
  Future<List<OrbitMediaReceipt>> retryPending({
    void Function(double fraction)? onProgress,
    Future<void> Function(String transfer,OrbitSealedMedia original,
      OrbitSealedMedia? derivative,String mediaId)? onRecovered,
    bool Function(OrbitQueuedMedia parent)? shouldRetry,
    Future<void> Function(OrbitQueuedMedia parent)? onRetryStart,
  }) async {
    return OrbitMediaTransferGate.run(() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)return [];
    final results=<OrbitMediaReceipt>[];
    final drafts=await _outbox.pending(owner);
    for(final parent in drafts.where((x)=>x.variant=='original')) {
      if(shouldRetry!=null && !shouldRetry(parent))continue;
      if(onRetryStart!=null)await onRetryStart(parent);
      final sealed=await _outbox.restore(parent);
      final main=await _repo.upload(sealed,kind:parent.kind,mime:parent.mime,
        width:parent.width,height:parent.height,durationMs:parent.durationMs,
        onProgress:onProgress);
      results.add(main);
      if(!main.ready)continue;
      final allEnvelopes=<Map<String,Object?>>[];
      final children=drafts.where((x)=>x.parentTransferId==parent.transfer)
          .toList();
      // A crash between enqueuing original and derivative is NOT a complete
      // photo/video upload. Never grant/discard a Moment without its variant.
      if(parent.purpose=='moment' &&
          (parent.kind=='image' || parent.kind=='video') &&
          children.isEmpty) continue;
      final refreshedChildren=<OrbitQueuedMedia>[];
      var complete=true;
      for(var child in children) {
        // The backend can issue a fresh parent UUID after a 2+ hour
        // expired-session recovery. Rebind a previously saved child as well.
        if(child.parentMediaId!=main.mediaId) {
          child=await _outbox.bindVariantParent(child,main.mediaId);
        }
        final sent=await _repo.upload(await _outbox.restore(child),
          kind:child.kind,mime:child.mime,parentMediaId:main.mediaId,
          onProgress:onProgress);
        results.add(sent);
        if(!sent.ready){complete=false;break;}
        refreshedChildren.add(child);
      }
      if(!complete)continue;
      final device=await _identity.trustedMediaDevice();
      final grantDraft=await _outbox.grantEnvelopeOnce(owner,parent.transfer,
        () async {
          final envelopes=<Map<String,Object?>>[
            {'device_id':device.id,'variant':'original','key_version':'v1',
              'algorithm':OrbitMediaFormat.envelopeAlgorithm,
              'wrapped_key_ciphertext':await _crypto.wrapKey(
                sealed,device.publicKey)},
          ];
          for(final child in refreshedChildren) {
            final saved=await _outbox.restore(child);
            envelopes.add({
              'device_id':device.id,'variant':child.variant,
              'key_version':'v1','algorithm':OrbitMediaFormat.envelopeAlgorithm,
              'wrapped_key_ciphertext':await _crypto.wrapKey(
                saved,device.publicKey),
            });
          }
          return envelopes;
        });
      allEnvelopes.addAll(grantDraft);
      final granted=await _repo.createGrants(main.mediaId,
        audience:'only_me',recipients:const [],
        keyEnvelopes:allEnvelopes,idempotencyKey:parent.transfer);
      if(granted.isEmpty)throw StateError('Encrypted media grant not confirmed.');
      // M7 publication uses the OS-vault-preserved account consent; a failed
      // network commit MUST keep M6 encrypted drafts for another attempt.
      if(onRecovered!=null){
        OrbitSealedMedia? derivative;
        if(refreshedChildren.isNotEmpty){
          derivative=await _outbox.restore(refreshedChildren.first);
        }
        await onRecovered(parent.transfer,sealed,derivative,main.mediaId);
      }
      for(final child in refreshedChildren){await _outbox.discard(child);}
      await _outbox.discard(parent);
    }
    return results;
    });
  }

}
