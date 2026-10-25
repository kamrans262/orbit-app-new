import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../media/data/orbit_media_outbox.dart';

class OrbitOfflineMomentPreview {
  const OrbitOfflineMomentPreview({
    required this.id,required this.mediaId,required this.creatorId,
    required this.contextId,required this.publishedAt,
    required this.leaseExpiresAt,required this.bytes,
  });
  final String id,mediaId,creatorId,contextId;
  final DateTime publishedAt,leaseExpiresAt;
  final Uint8List bytes;
}

/// M7 account-bound encrypted preview cache, never a permanent authorization
/// or an offline full-resolution media archive. Up to eight thumbnails,
/// 128 KiB each, and an authenticated five-minute server lease per item.
/// Revocations are reconciled when the device next contacts Laravel.
class OrbitMomentOfflineCache {
  OrbitMomentOfflineCache({OrbitMediaVault? vault,
    Future<String?> Function()? owner,
    Future<Directory> Function()? directory})
    : _vault=vault??OrbitPlatformMediaVault(),
      _owner=owner??OrbitIdentityClient.instance.currentLocalSocialOwner,
      _directory=directory??getApplicationSupportDirectory;
  final OrbitMediaVault _vault;
  final Future<String?> Function() _owner;
  final Future<Directory> Function() _directory;
  final AesGcm _cipher=AesGcm.with256bits();
  static const maxEntries=8;
  static const maxPreviewBytes=128*1024;
  static const lease=Duration(minutes:5);
  final Random _rng=Random.secure();

  String _index(String account)=>'orbit.m7.read-index.$account';
  String _key(String account)=>'orbit.m7.read-key.$account';
  String _lastClock(String account)=>'orbit.m7.last-clock.$account';
  String _digest(String id,String context)=>
    hashes.sha256.convert(utf8.encode('$id|$context')).toString();
  Future<Directory> _root(String account) async {
    final base=await _directory();
    final safe=account.replaceAll(RegExp(r'[^A-Za-z0-9_-]'),'_');
    final dir=Directory('${base.path}/orbit-m7-private-read/$safe');
    await dir.create(recursive:true);
    return dir;
  }
  Future<String> _account() async {
    final current=await _owner();
    if(current==null || current.isEmpty)throw StateError('Orbit sign-in required.');
    return current;
  }

  Future<void> _verifyClock(String account) async {
    final now=DateTime.now().toUtc();
    final last=await _vault.read(_lastClock(account));
    final seen=last==null?null:DateTime.tryParse(last)?.toUtc();
    if(seen!=null && now.isBefore(seen.subtract(const Duration(seconds:30)))){
      await purge(account);
      throw StateError('Device clock changed; offline lease invalid.');
    }
    await _vault.write(_lastClock(account),now.toIso8601String());
  }

  Future<List<Map<String,dynamic>>> _entries(String account) async {
    final raw=await _vault.read(_index(account));
    if(raw==null)return [];
    final decoded=jsonDecode(raw);
    if(decoded is! List)throw const FormatException('Moment cache index invalid.');
    return decoded.map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  }

  Future<Uint8List> _secret(String account) async {
    final encoded=await _vault.read(_key(account));
    if(encoded!=null){
      final bytes=base64Decode(encoded);
      if(bytes.length!=32)throw const FormatException('Cache key invalid.');
      return Uint8List.fromList(bytes);
    }
    final fresh=Uint8List.fromList(List.generate(32,(_)=>_rng.nextInt(256)));
    await _vault.write(_key(account),base64Encode(fresh));
    return fresh;
  }

  Future<void> save({
    required String id,required String mediaId,required String creatorId,
    required String contextId,required DateTime publishedAt,
    required DateTime issuedAt,required DateTime expiresAt,
    required DateTime viewExpiresAt,required Uint8List preview,
  }) async {
    final account=await _account();
    await _verifyClock(account);
    final now=DateTime.now().toUtc();
    final issued=issuedAt.toUtc(),end=expiresAt.toUtc();
    if(preview.isEmpty || preview.length>maxPreviewBytes ||
        issued.isBefore(now.subtract(const Duration(minutes:2))) ||
        issued.isAfter(now.add(const Duration(minutes:2))) ||
        !end.isAfter(now) || end.isAfter(issued.add(lease)) ||
        end.isAfter(viewExpiresAt.toUtc()) ||
        end.isAfter(publishedAt.toUtc().add(const Duration(days:7)))){
      throw const FormatException('Invalid short-term Moment cache lease.');
    }
    final validId=RegExp(r'^[a-fA-F0-9-]{36}$');
    if(!validId.hasMatch(id)||!validId.hasMatch(mediaId) ||
       !validId.hasMatch(creatorId))throw const FormatException('Invalid Moment identity.');
    final bytes=await _secret(account);
    final nonce=Uint8List.fromList(List.generate(12,(_)=>_rng.nextInt(256)));
    final aad=utf8.encode('$account|$id|$contextId|${end.toIso8601String()}');
    final box=await _cipher.encrypt(preview,
      secretKey:SecretKey(bytes),nonce:nonce,aad:aad);
    final file=File('${(await _root(account)).path}/${_digest(id,contextId)}.cipher');
    final tmp=File('${file.path}.tmp');
    try {
      await tmp.writeAsBytes([...nonce,...box.mac.bytes,...box.cipherText],flush:true);
      if(await file.exists())await file.delete();
      await tmp.rename(file.path);
      var index=await _entries(account);
      index.removeWhere((row)=>row['id']==id && row['context']==contextId);
      index.insert(0,{
        'id':id,'media_id':mediaId,'creator_id':creatorId,
        'context':contextId,'published_at':publishedAt.toUtc().toIso8601String(),
        'until':end.toIso8601String(),'file':file.uri.pathSegments.last,
      });
      if(index.length>maxEntries){
        final root=await _root(account);
        for(final older in index.skip(maxEntries)){
          final name=older['file'];
          if(name is String && RegExp(r'^[a-f0-9]{64}\.cipher$').hasMatch(name)){
            try{await File('${root.path}/$name').delete();}catch(_){}
          }
        }
        index=index.take(maxEntries).toList();
      }
      await _vault.write(_index(account),jsonEncode(index));
    }finally{
      if(await tmp.exists())await tmp.delete();
      bytes.fillRange(0,bytes.length,0);
    }
  }

  Future<List<OrbitOfflineMomentPreview>> read() async {
    final account=await _account();
    await _verifyClock(account);
    final now=DateTime.now().toUtc();
    final entries=await _entries(account);
    final root=await _root(account);
    final key=await _secret(account);
    final available=<OrbitOfflineMomentPreview>[];
    final keep=<Map<String,dynamic>>[];
    try{
      for(final entry in entries.take(maxEntries)){
        try{
          final end=DateTime.parse(entry['until'] as String).toUtc();
          final published=DateTime.parse(entry['published_at'] as String).toUtc();
          final name=entry['file'] as String;
          final id=entry['id'] as String,context=entry['context'] as String;
          if(!now.isBefore(end) ||
              now.isAfter(published.add(const Duration(days:7))) ||
              !RegExp(r'^[a-f0-9]{64}\.cipher$').hasMatch(name))continue;
          final file=File('${root.path}/$name');
          if(!await file.exists()||await file.length()>maxPreviewBytes+28)continue;
          final cipherBytes=await file.readAsBytes();
          if(cipherBytes.length<29)continue;
          final plain=await _cipher.decrypt(SecretBox(
            cipherBytes.sublist(28),nonce:cipherBytes.sublist(0,12),
            mac:Mac(cipherBytes.sublist(12,28))),
            secretKey:SecretKey(key),
            aad:utf8.encode('$account|$id|$context|${end.toIso8601String()}'));
          available.add(OrbitOfflineMomentPreview(
            id:id,mediaId:entry['media_id'] as String,
            creatorId:entry['creator_id'] as String,contextId:context,
            publishedAt:published,leaseExpiresAt:end,
            bytes:Uint8List.fromList(plain)));
          keep.add(entry);
        }catch(_){
          // Corrupt or replaced ciphertext is never returned.
        }
      }
      await _vault.write(_index(account),jsonEncode(keep));
      return available;
    }finally{
      key.fillRange(0,key.length,0);
    }
  }

  /// Called only following a fresh successful authenticated feed response.
  Future<void> reconcile(Set<String> authorized) async {
    final account=await _account();
    final root=await _root(account);
    final entries=await _entries(account);
    final keep=<Map<String,dynamic>>[];
    for(final e in entries){
      final id=e['id'];
      if(id is String && authorized.contains(id)){
        keep.add(e);continue;
      }
      final name=e['file'];
      if(name is String && RegExp(r'^[a-f0-9]{64}\.cipher$').hasMatch(name)){
        try{await File('${root.path}/$name').delete();}catch(_){}
      }
    }
    await _vault.write(_index(account),jsonEncode(keep));
  }

  /// Logout, account switch or erasure must not retain readable cache keys.
  /// Accepting an explicit account is safe: it can only erase local data.
  Future<void> purge(String account) async {
    await _vault.delete(_key(account));
    await _vault.delete(_index(account));
    await _vault.delete(_lastClock(account));
    final base=await _directory();
    final safe=account.replaceAll(RegExp(r'[^A-Za-z0-9_-]'),'_');
    final root=Directory('${base.path}/orbit-m7-private-read/$safe');
    if(await root.exists())await root.delete(recursive:true);
  }
}
