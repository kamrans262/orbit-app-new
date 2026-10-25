import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:orbit_ui/features/media/data/orbit_media_crypto.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('orbit-m6-test'));
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('Authenticated media roundtrip and ciphertext tamper detection', () async {
    final crypto = OrbitMediaCrypto();
    final data = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));
    final sealed = await crypto.sealBytes(data,
        destination: File(tmp.path + '/sealed.bin'), ownerId: 'owner',
        transferId: 'transfer', purpose: 'moment');
    final ciphertext = await sealed.file.readAsBytes();
    expect(sealed.bytes, 4112);
    expect(sealed.sha256, hasLength(64));
    expect(await crypto.openInMemory(ciphertext, key: sealed.key,
        noncePrefix: sealed.noncePrefix, ownerId: 'owner',
        transferId: 'transfer', purpose: 'moment',
        variant: 'original'), data);
    ciphertext[0] ^= 1;
    await expectLater(crypto.openInMemory(ciphertext, key: sealed.key,
        noncePrefix: sealed.noncePrefix, ownerId: 'owner',
        transferId: 'transfer', purpose: 'moment', variant: 'original'),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('Authenticated purpose and owner prevent ciphertext substitution', () async {
    final crypto = OrbitMediaCrypto();
    final sealed = await crypto.sealBytes(Uint8List.fromList([3,4,5]),
      destination: File(tmp.path + '/sealed.bin'), ownerId: 'owner',
      transferId: 'transfer', purpose: 'avatar');
    await expectLater(crypto.openInMemory(await sealed.file.readAsBytes(),
      key: sealed.key, noncePrefix: sealed.noncePrefix, ownerId: 'other',
      transferId: 'transfer', purpose: 'avatar', variant: 'original'),
      throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('X25519 wrapped media key is valid only for recipient device', () async {
    final crypto = OrbitMediaCrypto();
    final sealed = await crypto.sealBytes(Uint8List.fromList([1,2,3]),
      destination: File(tmp.path + '/sealed.bin'), ownerId:'owner',
      transferId:'transfer', purpose:'moment');
    final receiver = await X25519().newKeyPair();
    final receiverPublic = await receiver.extractPublicKey();
    final encoded = await crypto.wrapKey(sealed, receiverPublic.bytes);
    final recovered = await crypto.unwrapKey(encoded,
      privateKey: await receiver.extractPrivateKeyBytes(),
      publicKey: receiverPublic.bytes);
    expect(recovered.key, sealed.key);
    expect(recovered.prefix, sealed.noncePrefix);
    final impostor = await X25519().newKeyPair();
    final impostorPublic = await impostor.extractPublicKey();
    await expectLater(crypto.unwrapKey(encoded,
      privateKey: await impostor.extractPrivateKeyBytes(),
      publicKey: impostorPublic.bytes),
      throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('Photos are resized to 1440px and thumbnail generated locally', () {
    final photo = img.Image(width: 1800, height: 900);
    img.fill(photo, color: img.ColorRgb8(120, 34, 45));
    final result = OrbitMediaCrypto.preparePhoto(
        Uint8List.fromList(img.encodePng(photo)));
    expect(result.width, 1440);
    expect(result.height, 720);
    expect(img.decodeImage(result.thumbnail)?.width, 320);
    expect(result.jpeg, isNotEmpty);
    expect(() => OrbitMediaCrypto.preparePhoto(Uint8List.fromList([1,2])),
      throwsFormatException);
  });
}
