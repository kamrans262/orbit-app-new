import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:http/http.dart' as http;

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_media_crypto.dart';

class OrbitMediaReceipt {
  const OrbitMediaReceipt(this.mediaId, this.uploadId, this.state,
      {this.variant = 'original'});
  final String mediaId, uploadId, state, variant;
  bool get ready => state == 'ready';
}

/// Backend-neutral ciphertext transfer; never performs a public-disk fallback.
/// All control requests use the existing trusted-device Orbit session.
class OrbitMediaRepository {
  OrbitMediaRepository({OrbitIdentityClient? identity, http.Client? client})
      : _identity = identity ?? OrbitIdentityClient.instance,
        _http = client ?? http.Client();
  final OrbitIdentityClient _identity;
  final http.Client _http;

  Future<Map<String, dynamic>> control(String method, String path,
      {Map<String, Object?>? body, String? idempotencyKey}) async {
    final result = await _identity.socialRequest(method, path,
        body: body, idempotencyKey: idempotencyKey);
    if (result['data'] is! Map) {
      throw const FormatException('Invalid Orbit media response.');
    }
    return Map<String, dynamic>.from(result['data'] as Map);
  }

  Future<OrbitMediaReceipt> upload(OrbitSealedMedia media, {
    required String kind, required String mime,
    int? width, int? height, int? durationMs, String? parentMediaId,
    void Function(double)? onProgress,
  }) async {
    if (media.bytes <= 0 || !await media.file.exists() ||
        await media.file.length() != media.bytes) {
      throw const FileSystemException('Encrypted upload file is unavailable.');
    }
    final isVariant = parentMediaId != null;
    final route = isVariant
        ? '/media/' + Uri.encodeComponent(parentMediaId) + '/variants/uploads'
        : '/media/uploads';
    final init = await control('POST', route,
        idempotencyKey: media.transferId,
        body: isVariant
          ? {'variant':media.variant,'declared_bytes':media.bytes,
              'cipher_sha256':media.sha256}
          : {'purpose':media.purpose,'kind':kind,'declared_mime':mime,
              'declared_bytes':media.bytes,'cipher_suite':OrbitMediaFormat.suite,
              if (width != null) 'declared_width':width,
              if (height != null) 'declared_height':height,
              if (durationMs != null) 'declared_duration_ms':durationMs});
    final id = init['media_id'], upload = init['upload_id'];
    if (id is! String || upload is! String) {
      throw const FormatException('Missing media upload identifiers.');
    }
    final path = '/media/uploads/' + Uri.encodeComponent(upload);
    final mode = init['storage_mode'];
    if (!['multipart','local_chunked'].contains(mode) && init['state'] != 'ready') {
      // Hostinger local_chunked must have its own backend transport before
      // this client can use it; never assume storage/app/public is private.
      throw StateError('Private media transport is not configured.');
    }
    final partBytes = init['part_size_bytes'];
    if (init['state'] != 'ready' &&
        (partBytes is! int || partBytes<=0 || partBytes>OrbitMediaFormat.partBytes ||
         (mode=='multipart' && partBytes!=OrbitMediaFormat.partBytes))) {
      throw StateError('Backend multipart size differs from AEAD framing.');
    }
    if (init['state'] == 'ready') {
      onProgress?.call(1);
      return OrbitMediaReceipt(id, upload, 'ready', variant:media.variant);
    }
    final status = await control('GET', path);
    if (status['state'] == 'verifying' || status['state'] == 'ready') {
      return waitForReady(id, upload, variant:media.variant);
    }
    if (!['initiated','uploading'].contains(status['state'])) {
      throw StateError('Encrypted upload session cannot resume.');
    }
    final uploaded = <int,String>{};
    if (status['uploaded_parts'] is List) {
      for (final part in status['uploaded_parts'] as List) {
        if (part is Map && part['part_number'] is num && part['etag'] is String) {
          uploaded[(part['part_number'] as num).toInt()] = part['etag'] as String;
        }
      }
    }
    final pieces = <Map<String,Object>>[];
    var offset = 0;
    final file = await media.file.open();
    try {
      final count = (media.bytes / partBytes).ceil();
      for (var index = 1; index <= count; index++) {
        final size = min(partBytes, media.bytes - offset);
        final bytes = await file.read(size);
        if (bytes.length != size) throw const FileSystemException(
            'Ciphertext file changed during transfer.');
        var etag = uploaded[index];
        if (etag == null) {
          final checksumBytes = digest.sha256.convert(bytes).bytes;
          if (mode=='local_chunked') {
            final raw=await _identity.mediaBinaryRequest('PUT',
              path+'/chunks/$index',body:Uint8List.fromList(bytes),
              headers:{'X-Orbit-Cipher-SHA256':digest.sha256.convert(bytes).toString()},
              maxResponseBytes:4096);
            final decoded=jsonDecode(utf8.decode(raw));
            if(decoded is! Map || decoded['data'] is! Map ||
               (decoded['data'] as Map)['etag'] is! String) {
              throw const FormatException('Private chunk receipt invalid.');
            }
            etag=(decoded['data'] as Map)['etag'] as String;
          } else {
          final signed = await control('POST', path + '/parts', body: {
            'part_number':index,'checksum_sha256':digest.sha256.convert(bytes).toString(),
            'content_length':size,
          });
          final rawUrl = signed['url'], rawHeaders = signed['required_headers'];
          final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
          if (url == null || url.scheme != 'https' ||
              url.host.isEmpty || url.userInfo.isNotEmpty ||
              rawHeaders is! Map) {
            throw const FormatException('Invalid signed private-upload URL.');
          }
          final request = http.Request('PUT',url);
          for (final h in rawHeaders.entries) {
            final key = h.key.toString().toLowerCase();
            if (key != 'content-length' && key != 'x-amz-checksum-sha256') {
              throw const FormatException('Unexpected signed upload header.');
            }
            if (key == 'content-length' && h.value.toString() != '$size') {
              throw const FormatException('Upload size signature mismatch.');
            }
            if (key == 'x-amz-checksum-sha256' &&
                h.value.toString() != base64Encode(checksumBytes)) {
              throw const FormatException('Upload checksum signature mismatch.');
            }
            request.headers[h.key.toString()] = h.value.toString();
          }
          request.bodyBytes = Uint8List.fromList(bytes);
          final response = await _http.send(request)
              .timeout(const Duration(seconds:90));
          await response.stream.drain<void>();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw StateError('Encrypted part upload failed; safe to retry.');
          }
          etag = response.headers['etag'];
          if (etag == null || etag.isEmpty) {
            throw StateError('Storage server did not acknowledge ciphertext.');
          }
          }
        }
        pieces.add({'part_number':index,'etag':etag});
        offset += size;
        onProgress?.call(offset/media.bytes);
      }
    } finally {
      await file.close();
    }
    final completed = await control('POST',path + '/complete',
      idempotencyKey:media.transferId,
      body: {'total_cipher_bytes':media.bytes,
        'cipher_sha256':media.sha256,'parts':pieces});
    if (completed['state'] == 'ready') {
      return OrbitMediaReceipt(id,upload,'ready',variant:media.variant);
    }
    return waitForReady(id,upload,variant:media.variant);
  }

  Future<OrbitMediaReceipt> waitForReady(String mediaId,String uploadId, {
    String variant = 'original', int attempts = 8,
  }) async {
    for(var i=0;i<attempts;i++) {
      final status=await control('GET','/media/uploads/'+Uri.encodeComponent(uploadId));
      final state=status['state'];
      if(state == 'ready')return OrbitMediaReceipt(
          mediaId,uploadId,'ready',variant:variant);
      if(!['verifying','initiated','uploading'].contains(state)) {
        throw StateError('Ciphertext verification was rejected.');
      }
      if(i+1<attempts)await Future<void>.delayed(const Duration(seconds:2));
    }
    return OrbitMediaReceipt(mediaId,uploadId,'verifying',variant:variant);
  }

  /// No optimistic grants: require Laravel to return grant IDs.
  Future<List<String>> createGrants(String mediaId, {
    required String audience, required List<String> recipients,
    required List<Map<String,Object?>> keyEnvelopes,
    required String idempotencyKey,
  }) async {
    final data=await control('POST','/media/'+Uri.encodeComponent(mediaId)+'/grants',
      idempotencyKey:idempotencyKey,body:{
        'audience_kind':audience,'target_ids':recipients,
        'key_envelopes':keyEnvelopes,
      });
    if(data['grant_ids'] is! List)throw StateError('Media grant not confirmed.');
    return (data['grant_ids'] as List).cast<String>();
  }

  /// Authenticated short-lived URL plus current device envelope; no public URL
  /// ever cached. Decrypt only after SHA256 and AEAD verification.
  Future<Uint8List> downloadPhoto(String mediaId, {
    required String deviceId, required List<int> privateKey,
    required List<int> publicKey, String variant='original',
    OrbitMediaCrypto? crypto,
    int? maxPlainBytes,
  }) async {
    final scope='/media/'+Uri.encodeComponent(mediaId);
    final access=await control('POST',scope+'/access',
        body:{'variant':variant,'device_id':deviceId});
    final envelope=await control('GET',scope+'/key-envelope?device_id='+
        Uri.encodeComponent(deviceId)+'&variant='+Uri.encodeComponent(variant));
    // Clip limits are explicitly caller-bounded; images keep the strict M6
    // image limit. No URL or plaintext is ever published or cached remotely.
    final maxBytes=maxPlainBytes??OrbitMediaFormat.imageLimit;
    if(maxBytes<=0||maxBytes>64*1024*1024) {
      throw StateError('Private media exceeds safe in-memory playback budget.');
    }
    late final Uint8List ciphertext;
    if(access['download_mode']=='authenticated') {
      final path=access['download_path'];
      if(path is! String || !path.startsWith('/media/')) {
        throw const FormatException('Invalid private ciphertext path.');
      }
      ciphertext=await _identity.mediaBinaryRequest('GET',path,
          maxResponseBytes:maxBytes+262144);
    } else {
      final raw=access['ciphertext_url'];
      final url=raw is String ? Uri.tryParse(raw):null;
      if(url==null || url.scheme!='https' || url.userInfo.isNotEmpty) {
        throw const FormatException('Invalid signed media read URL.');
      }
      final response=await _http.get(url).timeout(const Duration(seconds:60));
      if(response.statusCode!=200 ||
         response.bodyBytes.length>maxBytes+262144) {
        throw StateError('Private media cannot be downloaded.');
      }
      ciphertext=response.bodyBytes;
    }
    if(digest.sha256.convert(ciphertext).toString()!=access['sha256_ciphertext']) {
      throw StateError('Ciphertext checksum mismatch.');
    }
    final processor=crypto??OrbitMediaCrypto();
    final material=await processor.unwrapKey(
      envelope['wrapped_key_ciphertext'] as String,
      privateKey:privateKey,publicKey:publicKey);
    return processor.openInMemory(ciphertext,
      key:material.key,noncePrefix:material.prefix,
      ownerId:material.owner,transferId:material.transfer,
      purpose:material.purpose,variant:material.variant,maxPlainBytes:maxBytes);
  }
}
