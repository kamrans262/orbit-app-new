import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_crypto.dart';

void main() {
  test('Private video frames decrypt from file and reject altered ciphertext',
      () async {
    final folder=await Directory.systemTemp.createTemp('orbit_m13_ae_');
    try {
      final plain=Uint8List.fromList(
        List<int>.generate(128*1024,(i)=>i%251));
      final input=File('${folder.path}/capture.mp4');
      await input.writeAsBytes(plain,flush:true);
      final crypto=OrbitMediaCrypto();
      final sealed=await crypto.sealFile(input,
        destination:File('${folder.path}/sealed.cipher'),
        ownerId:'test-account',
        transferId:'123e4567-e89b-12d3-a456-426614174000',
        purpose:'message',
        maxInputBytes:OrbitMediaFormat.videoLimit);
      final destination=File('${folder.path}/private-video.mp4');
      await crypto.openFileToPrivateFile(sealed.file,
        destination:destination,key:sealed.key,
        noncePrefix:sealed.noncePrefix,ownerId:sealed.ownerId,
        transferId:sealed.transferId,purpose:sealed.purpose,
        variant:sealed.variant,expectedPlainBytes:sealed.plainBytes);
      expect(await destination.readAsBytes(),plain);

      await destination.delete();
      final modified=await sealed.file.readAsBytes();
      modified[0]^=1;
      await sealed.file.writeAsBytes(modified,flush:true);
      await expectLater(
        crypto.openFileToPrivateFile(sealed.file,
          destination:destination,key:sealed.key,
          noncePrefix:sealed.noncePrefix,ownerId:sealed.ownerId,
          transferId:sealed.transferId,purpose:sealed.purpose,
          variant:sealed.variant,expectedPlainBytes:sealed.plainBytes),
        throwsA(isA<Exception>()));
      expect(await destination.exists(),isFalse);
    }finally{
      if(await folder.exists())await folder.delete(recursive:true);
    }
  });
}
