import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_repository.dart';

void main(){
  test('author identity and private avatar come from authenticated feed data',(){
    final item=OrbitLiveMoment.fromJson({
      'id':'moment','creator_id':'user','media_id':'media','context_id':'self',
      'published_at':'2026-11-26T00:00:00Z','creator_display_name':'Example Person',
      'creator_avatar_media_id':'avatar',
    });
    expect(OrbitMomentRepository.firstName(item.creatorDisplayName),'Example');
    expect(item.creatorAvatarMediaId,'avatar');
    expect(OrbitMomentRepository.firstName(null),'Orbit member');
  });
}
