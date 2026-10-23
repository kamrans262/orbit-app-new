import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_media_crypto.dart';

/// Abstracted only for deterministic tests. Production implementation is
/// OS-backed FlutterSecureStorage. No content key ever enters SharedPreferences.
abstract class OrbitMediaVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class OrbitPlatformMediaVault implements OrbitMediaVault {
  OrbitPlatformMediaVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class OrbitQueuedMedia {
  const OrbitQueuedMedia({
    required this.owner, required this.transfer, required this.purpose,
    required this.kind, required this.mime, required this.variant,
    required this.fileName, required this.cipherSha256,
    required this.cipherBytes, required this.plainBytes,
    required this.noncePrefix, this.parentMediaId, this.parentTransferId,
    this.width, this.height, this.durationMs,
  });
  final String owner, transfer, purpose, kind, mime, variant;
  final String fileName, cipherSha256, noncePrefix;
  final int cipherBytes, plainBytes;
  final String? parentMediaId, parentTransferId;
  final int? width, height, durationMs;
  Map<String, Object?> toJson() => {
    'owner':owner,'transfer':transfer,'purpose':purpose,
    'kind':kind,'mime':mime,'variant':variant,
    'file_name':fileName,'cipher_sha256':cipherSha256,
    'cipher_bytes':cipherBytes,'plain_bytes':plainBytes,
    'nonce_prefix':noncePrefix,'parent_media_id':parentMediaId,
    'parent_transfer_id':parentTransferId,
    'width':width,'height':height,'duration_ms':durationMs,
  };
  factory OrbitQueuedMedia.fromJson(Map<String, dynamic> j) => OrbitQueuedMedia(
    owner:j['owner'] as String, transfer:j['transfer'] as String,
    purpose:j['purpose'] as String, kind:j['kind'] as String,
    mime:j['mime'] as String, variant:j['variant'] as String,
    fileName:j['file_name'] as String,
    cipherSha256:j['cipher_sha256'] as String,
    cipherBytes:(j['cipher_bytes'] as num).toInt(),
    plainBytes:(j['plain_bytes'] as num).toInt(),
    noncePrefix:j['nonce_prefix'] as String,
    parentMediaId:j['parent_media_id'] as String?,
    parentTransferId:j['parent_transfer_id'] as String?,
    width:(j['width'] as num?)?.toInt(),
    height:(j['height'] as num?)?.toInt(),
    durationMs:(j['duration_ms'] as num?)?.toInt(),
  );
}

/// The persistent outbox holds **ciphertext only** on private app storage.
/// Its per-account index and content keys use OS secure storage; every read
/// also checks the currently signed-in identity. No background network worker,
/// UI toast, Firebase subscription or upload on account switch is implied.
class OrbitMediaOutbox {
  OrbitMediaOutbox({OrbitMediaVault? vault,
      Future<String?> Function()? signedInOwner,
      Future<Directory> Function()? supportDirectory})
      : _vault = vault ?? OrbitPlatformMediaVault(),
        _owner = signedInOwner ??
            OrbitIdentityClient.instance.currentLocalSocialOwner,
        _directory = supportDirectory ?? getApplicationSupportDirectory;
  final OrbitMediaVault _vault;
  final Future<String?> Function() _owner;
  final Future<Directory> Function() _directory;

  Future<String> _requireOwner(String expected) async {
    final owner = await _owner();
    if (owner == null || owner != expected) {
      throw StateError('Media belongs to a different Orbit account.');
    }
    return owner;
  }

  String _indexKey(String owner) => 'orbit.m6.pending.' + owner;
  String _keyName(String owner,String transfer) =>
      'orbit.m6.contentkey.' + owner + '.' + transfer;

  Future<Directory> _root(String owner) async {
    final base = await _directory();
    final safe = owner.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final root = Directory(base.path + '/orbit-m6-encrypted-outbox/' + safe);
    await root.create(recursive:true);
    return root;
  }

  Future<List<OrbitQueuedMedia>> _load(String owner) async {
    final raw = await _vault.read(_indexKey(owner));
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Invalid secure media queue.');
    return decoded.map((e) => OrbitQueuedMedia.fromJson(
        Map<String,dynamic>.from(e as Map))).toList();
  }

  Future<void> _save(String owner,List<OrbitQueuedMedia> drafts) async =>
      _vault.write(_indexKey(owner),
          jsonEncode(drafts.map((d)=>d.toJson()).toList()));

  Future<List<OrbitQueuedMedia>> pending(String owner) async {
    await _requireOwner(owner);
    return List<OrbitQueuedMedia>.unmodifiable(await _load(owner));
  }

  /// Keep an idempotent encrypted draft and its random key in OS secure
  /// storage. [sealed.file] may be a temporary file outside this directory.
  Future<OrbitQueuedMedia> enqueue(OrbitSealedMedia sealed, {
    required String kind, required String mime, String? parentMediaId,
    String? parentTransferId,
    int? width, int? height, int? durationMs,
  }) async {
    await _requireOwner(sealed.ownerId);
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(sealed.transferId)) {
      throw const FormatException('Transfer ID must be a UUID.');
    }
    if (sealed.sha256.length != 64) {
      throw const FormatException('Invalid encrypted media checksum.');
    }
    final root=await _root(sealed.ownerId);
    final name=sealed.transferId + '-' + sealed.variant + '.cipher';
    final saved=File(root.path + '/' + name);
    if (sealed.file.absolute.path != saved.absolute.path) {
      await sealed.file.copy(saved.path);
    }
    final sum=await digest.sha256.bind(saved.openRead()).first;
    if (sum.toString()!=sealed.sha256) {
      await saved.delete();
      throw StateError('Encrypted outbox checksum mismatch.');
    }
    final item=OrbitQueuedMedia(owner:sealed.ownerId,
      transfer:sealed.transferId,purpose:sealed.purpose,
      kind:kind,mime:mime,variant:sealed.variant,
      fileName:name,cipherSha256:sealed.sha256,
      cipherBytes:sealed.bytes,plainBytes:sealed.plainBytes,
      noncePrefix:base64Encode(sealed.noncePrefix),
      parentMediaId:parentMediaId,parentTransferId:parentTransferId,
      width:width,height:height,
      durationMs:durationMs);
    final entries=await _load(sealed.ownerId);
    entries.removeWhere((d)=>d.transfer==item.transfer);
    entries.add(item);
    await _vault.write(_keyName(sealed.ownerId,sealed.transferId),
        base64Encode(sealed.key));
    await _save(sealed.ownerId,entries);
    return item;
  }

  /// Every resumed send re-hashes ciphertext so a changed, missing, or stale
  /// local file never becomes trusted encrypted data.
  Future<OrbitSealedMedia> restore(OrbitQueuedMedia item) async {
    await _requireOwner(item.owner);
    final root=await _root(item.owner);
    if (item.fileName.contains('/') || item.fileName.contains('..')) {
      throw const FormatException('Invalid encrypted file name.');
    }
    final file=File(root.path + '/' + item.fileName);
    if (!await file.exists() || await file.length()!=item.cipherBytes) {
      throw const FileSystemException('Encrypted outbox file is missing.');
    }
    final hash=await digest.sha256.bind(file.openRead()).first;
    if (hash.toString()!=item.cipherSha256) {
      throw StateError('Outbox ciphertext was modified.');
    }
    final encoded=await _vault.read(_keyName(item.owner,item.transfer));
    if (encoded==null) throw StateError('Encrypted media key unavailable.');
    final key=base64Decode(encoded);
    final nonce=base64Decode(item.noncePrefix);
    if (key.length!=32 || nonce.length!=8) {
      throw const FormatException('Invalid secured media key.');
    }
    return OrbitSealedMedia(file:file,key:Uint8List.fromList(key),
      noncePrefix:nonce,plainBytes:item.plainBytes,bytes:item.cipherBytes,
      sha256:item.cipherSha256,ownerId:item.owner,transferId:item.transfer,
      purpose:item.purpose,variant:item.variant);
  }


  /// Persist the parent media UUID after an original is verified so a
  /// thumbnail can resume independently after connectivity is restored.
  Future<OrbitQueuedMedia> bindVariantParent(OrbitQueuedMedia item,
      String parentMediaId) async {
    await _requireOwner(item.owner);
    final drafts=await _load(item.owner);
    final index=drafts.indexWhere((d)=>d.transfer==item.transfer);
    if(index<0)throw StateError('Offline media job disappeared.');
    final updated=OrbitQueuedMedia(
      owner:item.owner,transfer:item.transfer,purpose:item.purpose,
      kind:item.kind,mime:item.mime,variant:item.variant,
      fileName:item.fileName,cipherSha256:item.cipherSha256,
      cipherBytes:item.cipherBytes,plainBytes:item.plainBytes,
      noncePrefix:item.noncePrefix,parentMediaId:parentMediaId,
      parentTransferId:item.parentTransferId,
      width:item.width,height:item.height,durationMs:item.durationMs,
    );
    drafts[index]=updated;
    await _save(item.owner,drafts);
    return updated;
  }


  String _grantKey(String owner,String transfer) =>
      'orbit.m6.grant.' + owner + '.' + transfer;

  /// Reusing one idempotency key is insufficient if X25519 wraps generate
  /// new random ephemeral keys at retry. Persist the EXACT grant request in
  /// secure storage before network use; then every retry has identical bytes.
  Future<List<Map<String,Object?>>> grantEnvelopeOnce(String owner,
      String rootTransfer,
      Future<List<Map<String,Object?>>> Function() generate) async {
    await _requireOwner(owner);
    final old=await _vault.read(_grantKey(owner,rootTransfer));
    if(old!=null) {
      final decoded=jsonDecode(old);
      if(decoded is! List)throw const FormatException('Invalid grant draft.');
      return decoded.map((e)=>Map<String,Object?>.from(e as Map)).toList();
    }
    final fresh=await generate();
    if(fresh.isEmpty)throw StateError('No encrypted device grants.');
    await _vault.write(_grantKey(owner,rootTransfer),jsonEncode(fresh));
    return fresh;
  }

  Future<void> discard(OrbitQueuedMedia item) async {
    await _requireOwner(item.owner);
    final entries=await _load(item.owner);
    entries.removeWhere((d)=>d.transfer==item.transfer);
    await _save(item.owner,entries);
    await _vault.delete(_keyName(item.owner,item.transfer));
    if(item.variant=='original')await _vault.delete(_grantKey(item.owner,item.transfer));
    final root=await _root(item.owner);
    final file=File(root.path + '/' + item.fileName);
    if (await file.exists()) await file.delete();
  }

  /// Old ciphertext can be deleted after explicit sign-out or account swap.
  /// Never transfer its key to another identity.
  Future<void> purge(String owner) async {
    final entries=await _load(owner);
    for(final item in entries) {
      await _vault.delete(_keyName(owner,item.transfer));
      if(item.variant=='original')await _vault.delete(_grantKey(owner,item.transfer));
    }
    await _vault.delete(_indexKey(owner));
    final root=await _root(owner);
    if(await root.exists())await root.delete(recursive:true);
  }
}
