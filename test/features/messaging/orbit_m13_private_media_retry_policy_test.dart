import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_repository.dart';

void main(){
  test('Encrypted private media parts use bounded original-spec backoff',(){
    final seconds=List<int>.generate(5,(attempt)=>
      OrbitMediaRepository.encryptedPartRetryDelay(attempt).inSeconds);
    expect(seconds,[1,2,4,8,16]);
    expect(OrbitMediaRepository.encryptedPartRetryDelay(-1),
      const Duration(seconds:1));
    expect(OrbitMediaRepository.encryptedPartRetryDelay(100),
      const Duration(seconds:16));
  });
}
