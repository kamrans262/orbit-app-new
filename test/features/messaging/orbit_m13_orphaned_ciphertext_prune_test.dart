import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_media_bridge.dart';

void main(){
  test('M13 90-day cleanup removes only old encrypted transfer leftovers',
      () async {
    final temp=await Directory.systemTemp.createTemp('orbit_m13_prune_test_');
    final now=DateTime.utc(2026,10,31,12);
    const id='4ec493c1-d21a-4eea-a09e-91566cbd5936';
    try{
      final stale=File('${temp.path}/orbit_m13_$id.cipher');
      final recent=File('${temp.path}/orbit_m13_'
        '6a0cd993-422d-4919-90f6-a8d44325efab.cipher');
      final foreign=File('${temp.path}/user_photo.cipher');
      await stale.writeAsBytes([1,2,3],flush:true);
      await recent.writeAsBytes([4,5],flush:true);
      await foreign.writeAsBytes([6],flush:true);
      await stale.setLastModified(now.subtract(const Duration(days:91)));
      await recent.setLastModified(now.subtract(const Duration(days:3)));
      await foreign.setLastModified(now.subtract(const Duration(days:200)));
      final removed=await OrbitMessagingMediaBridge.pruneOrphanedCiphertext(
        tempDirectory:temp,now:now);
      expect(removed,1);
      expect(await stale.exists(),isFalse);
      expect(await recent.exists(),isTrue);
      expect(await foreign.exists(),isTrue);
    }finally{
      if(await temp.exists())await temp.delete(recursive:true);
    }
  });
}
