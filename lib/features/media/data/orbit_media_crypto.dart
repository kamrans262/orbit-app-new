import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:image/image.dart' as img;

/// Ciphertext framing shared by R2 multipart and future Hostinger local chunks.
abstract final class OrbitMediaFormat {
  static const partBytes = 8 * 1024 * 1024;
  static const tagBytes = 16;
  static const plainChunkBytes = partBytes - tagBytes;
  static const suite = 'aes256gcm-v1';
  static const envelopeAlgorithm = 'x25519-hkdfsha256-aes256gcm-v1';
  static const imageLimit = 25 * 1024 * 1024;
  static const videoLimit = 250 * 1024 * 1024;
  static const audioLimit = 20 * 1024 * 1024;
}

class OrbitPreparedPhoto {
  const OrbitPreparedPhoto(this.jpeg, this.thumbnail, this.width, this.height);
  final Uint8List jpeg, thumbnail;
  final int width, height;
}

/// The content key stays on-device. Never serialize it to JSON, logs or disk.
class OrbitSealedMedia {
  const OrbitSealedMedia({required this.file, required this.key,
    required this.noncePrefix, required this.plainBytes, required this.bytes,
    required this.sha256, required this.ownerId, required this.transferId,
    required this.purpose, required this.variant});
  final File file;
  final Uint8List key, noncePrefix;
  final int plainBytes, bytes;
  final String sha256, ownerId, transferId, purpose, variant;
}

class OrbitMediaCrypto {
  OrbitMediaCrypto({AesGcm? cipher}) : _cipher = cipher ?? AesGcm.with256bits();
  final AesGcm _cipher;
  final Random _random = Random.secure();

  Uint8List randomBytes(int length) => Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)));

  static OrbitPreparedPhoto preparePhoto(Uint8List original) {
    if (original.isEmpty || original.length > OrbitMediaFormat.imageLimit) {
      throw const FormatException('Image exceeds the maximum size.');
    }
    img.Image? decoded;
    try { decoded = img.decodeImage(original); }
    catch (error) { throw const FormatException('Unsupported image.'); }
    if (decoded == null) throw const FormatException('Unsupported image.');
    final oriented = img.bakeOrientation(decoded);
    final ratio = min(1.0, 1440 / max(oriented.width, oriented.height));
    final width = max(1, (oriented.width * ratio).round());
    final height = max(1, (oriented.height * ratio).round());
    final resized = img.copyResize(oriented, width: width, height: height);
    // Brand-new image, not a copy of the source EXIF/GPS metadata.
    final clean = img.Image(width: width, height: height, numChannels: 3);
    img.compositeImage(clean, resized);
    final thumbWidth = min(320, width);
    final thumbHeight = max(1, (height * thumbWidth / width).round());
    final small = img.copyResize(clean, width: thumbWidth, height: thumbHeight);
    final thumbClean = img.Image(width: thumbWidth, height: thumbHeight,
        numChannels: 3);
    img.compositeImage(thumbClean, small);
    return OrbitPreparedPhoto(
      Uint8List.fromList(img.encodeJpg(clean, quality: 80)),
      Uint8List.fromList(img.encodeJpg(thumbClean, quality: 72)), width, height);
  }

  Uint8List _nonce(Uint8List prefix, int index) {
    if (prefix.length != 8 || index < 0 || index > 0xffffffff) {
      throw StateError('Invalid nonce index.');
    }
    final output = Uint8List(12)..setRange(0, 8, prefix);
    ByteData.sublistView(output).setUint32(8, index, Endian.big);
    return output;
  }

  List<int> _aad(String owner, String transfer, String purpose,
      String variant, int part) =>
      utf8.encode('orbit-m6-v1|$owner|$transfer|$purpose|$variant|$part');

  /// Encrypt bytes in memory (photos); only ciphertext is written to disk.
  Future<OrbitSealedMedia> sealBytes(Uint8List input, {
    required File destination, required String ownerId,
    required String transferId, required String purpose,
    String variant = 'original',
  }) async {
    if (input.isEmpty) throw const FormatException('Empty media.');
    Stream<List<int>> parts() async* {
      for (var i = 0; i < input.length; i += OrbitMediaFormat.plainChunkBytes) {
        yield Uint8List.sublistView(input, i,
            min(input.length, i + OrbitMediaFormat.plainChunkBytes));
      }
    }
    return _seal(parts(), destination, ownerId, transferId, purpose, variant);
  }

  /// Bounded-memory streaming for video and voice; source never overwritten.
  Future<OrbitSealedMedia> sealFile(File source, {
    required File destination, required String ownerId,
    required String transferId, required String purpose,
    required int maxInputBytes, String variant = 'original',
  }) async {
    final size = await source.length();
    if (size <= 0 || size > maxInputBytes) {
      throw const FormatException('Media size exceeds limit.');
    }
    if (source.absolute.path == destination.absolute.path) {
      throw ArgumentError('Source and destination must differ.');
    }
    final reader = await source.open();
    try {
      Stream<List<int>> parts() async* {
        while (true) {
          final part = await reader.read(OrbitMediaFormat.plainChunkBytes);
          if (part.isEmpty) break;
          yield part;
        }
      }
      return await _seal(parts(), destination, ownerId, transferId,
          purpose, variant);
    } finally {
      await reader.close();
    }
  }

  Future<OrbitSealedMedia> _seal(Stream<List<int>> parts, File destination,
      String owner, String transfer, String purpose, String variant) async {
    final key = randomBytes(32);
    final prefix = randomBytes(8);
    final output = destination.openWrite();
    var partNumber = 0, plainBytes = 0, cipherBytes = 0;
    try {
      await for (final part in parts) {
        if (part.isEmpty || part.length > OrbitMediaFormat.plainChunkBytes) {
          throw const FormatException('Invalid encrypted chunk boundary.');
        }
        final box = await _cipher.encrypt(part, secretKey: SecretKey(key),
            nonce: _nonce(prefix, partNumber),
            aad: _aad(owner, transfer, purpose, variant, partNumber));
        output.add(box.cipherText);
        output.add(box.mac.bytes);
        plainBytes += part.length;
        cipherBytes += part.length + OrbitMediaFormat.tagBytes;
        partNumber++;
      }
      if (partNumber == 0) throw const FormatException('Empty media.');
      await output.flush();
      await output.close();
      final digest = await hashes.sha256.bind(destination.openRead()).first;
      return OrbitSealedMedia(file: destination, key: key, noncePrefix: prefix,
          plainBytes: plainBytes, bytes: cipherBytes, sha256: digest.toString(),
          ownerId: owner, transferId: transfer, purpose: purpose,
          variant: variant);
    } catch (_) {
      await output.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  /// AEAD authenticated decryption into RAM for appropriately sized previews.
  Future<Uint8List> openInMemory(Uint8List ciphertext, {
    required Uint8List key, required Uint8List noncePrefix,
    required String ownerId, required String transferId,
    required String purpose, required String variant,
    int maxPlainBytes = OrbitMediaFormat.imageLimit,
  }) async {
    if (key.length != 32 || noncePrefix.length != 8 ||
        ciphertext.isEmpty || ciphertext.length > maxPlainBytes + 2048) {
      throw const FormatException('Encrypted media metadata invalid.');
    }
    final builder = BytesBuilder(copy: false);
    var offset = 0, index = 0;
    while (offset < ciphertext.length) {
      final len = min(OrbitMediaFormat.partBytes, ciphertext.length - offset);
      if (len <= OrbitMediaFormat.tagBytes) {
        throw const FormatException('Truncated ciphertext.');
      }
      final end = offset + len;
      final box = SecretBox(ciphertext.sublist(offset,
          end - OrbitMediaFormat.tagBytes), nonce: _nonce(noncePrefix, index),
          mac: Mac(ciphertext.sublist(end - OrbitMediaFormat.tagBytes, end)));
      final plain = await _cipher.decrypt(box, secretKey: SecretKey(key),
          aad: _aad(ownerId, transferId, purpose, variant, index));
      builder.add(plain);
      offset = end;
      index++;
    }
    return builder.toBytes();
  }

  /// Device-bound X25519 ECDH + HKDF authenticated key wrapping.
  /// The server sees this envelope but cannot derive the content key.
  Future<String> wrapKey(OrbitSealedMedia media, List<int> recipientPublic) async {
    if (recipientPublic.length != 32) {
      throw const FormatException('Expected X25519 recipient public key.');
    }
    final exchange = X25519();
    final ephemeral = await exchange.newKeyPair();
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final shared = await exchange.sharedSecretKey(keyPair: ephemeral,
      remotePublicKey: SimplePublicKey(recipientPublic,
          type: KeyPairType.x25519));
    final salt = randomBytes(24);
    final wrapping = await Hkdf(hmac: Hmac.sha256(), outputLength: 32)
        .deriveKey(secretKey: shared, nonce: salt,
            info: utf8.encode('orbit-m6-envelope-v1'));
    final metadata = <String, Object>{
      'v': 1, 'owner': media.ownerId, 'transfer': media.transferId,
      'purpose': media.purpose, 'variant': media.variant,
      'prefix': base64Encode(media.noncePrefix), 'length': media.plainBytes,
    };
    final nonce = randomBytes(12);
    final box = await _cipher.encrypt(media.key,
        secretKey: wrapping, nonce: nonce,
        aad: utf8.encode(jsonEncode(metadata)));
    return jsonEncode(<String, Object>{
      ...metadata, 'ephemeral': base64Encode(ephemeralPublic.bytes),
      'salt': base64Encode(salt), 'nonce': base64Encode(nonce),
      'data': base64Encode(box.cipherText), 'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<({Uint8List key, Uint8List prefix, String owner, String transfer,
      String purpose, String variant, int length})> unwrapKey(String encoded, {
    required List<int> privateKey, required List<int> publicKey,
  }) async {
    final map = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    if (map['v'] != 1 || privateKey.length != 32 || publicKey.length != 32) {
      throw const FormatException('Unknown envelope or invalid device key.');
    }
    final metadata = <String, Object>{
      for (final key in ['v','owner','transfer','purpose','variant','prefix','length'])
        key: map[key] as Object,
    };
    final shared = await X25519().sharedSecretKey(
      keyPair: SimpleKeyPairData(privateKey,
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.x25519),
          type: KeyPairType.x25519),
      remotePublicKey: SimplePublicKey(base64Decode(map['ephemeral'] as String),
          type: KeyPairType.x25519),
    );
    final wrapping = await Hkdf(hmac: Hmac.sha256(), outputLength: 32)
        .deriveKey(secretKey: shared,
            nonce: base64Decode(map['salt'] as String),
            info: utf8.encode('orbit-m6-envelope-v1'));
    final bytes = await _cipher.decrypt(SecretBox(
        base64Decode(map['data'] as String),
        nonce: base64Decode(map['nonce'] as String),
        mac: Mac(base64Decode(map['mac'] as String))),
        secretKey: wrapping, aad: utf8.encode(jsonEncode(metadata)));
    if (bytes.length != 32) throw const FormatException('Invalid media key.');
    return (key: Uint8List.fromList(bytes),
      prefix: base64Decode(map['prefix'] as String),
      owner: map['owner'] as String, transfer: map['transfer'] as String,
      purpose: map['purpose'] as String, variant: map['variant'] as String,
      length:map['length'] as int);
  }
}
