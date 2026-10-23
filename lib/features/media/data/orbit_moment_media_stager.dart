import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_media_crypto.dart';
import 'orbit_media_outbox.dart';
import 'orbit_media_repository.dart';

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
      {void Function(double fraction)? onProgress}) async {
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
      mime:'image/jpeg',width:320,
      height:(prepared.height*320/prepared.width).round());
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
        idempotencyKey:const Uuid().v4(),
        keyEnvelopes:[
          {'device_id':device.id,'variant':'original','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(original,device.publicKey)},
          {'device_id':device.id,'variant':'thumbnail','key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(thumb,device.publicKey)},
        ]);
      if(grantIds.isEmpty)throw StateError('Private media grant not confirmed.');
      onProgress?.call(1);
      await _outbox.discard(originalDraft);
      await _outbox.discard(thumbDraft);
      return OrbitStagedPhoto(mediaId:readyOriginal.mediaId,
        thumbnailVerified:true,privateGrantConfirmed:true);
    } catch (_) {
      // The outbox retains ciphertext and OS-backed keys for explicit retry.
      rethrow;
    }
  }

  /// User-initiated resume after reconnecting. It never sends while the
  /// account is missing or changed, nor confirms an M7 post.
  Future<List<OrbitMediaReceipt>> retryPending({
    void Function(double fraction)? onProgress,
  }) async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)return [];
    final results=<OrbitMediaReceipt>[];
    final drafts=await _outbox.pending(owner);
    for(final draft in drafts) {
      if(draft.variant!='original' && draft.parentMediaId==null)continue;
      final sealed=await _outbox.restore(draft);
      final receipt=await _repo.upload(sealed,kind:draft.kind,mime:draft.mime,
        width:draft.width,height:draft.height,durationMs:draft.durationMs,
        parentMediaId:draft.parentMediaId,onProgress:onProgress);
      results.add(receipt);
      // Do not discard a key before verified variant grants are available.
    }
    return results;
  }
}
