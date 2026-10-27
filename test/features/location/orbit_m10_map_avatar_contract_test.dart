import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/location/data/orbit_location_models.dart';
import 'package:orbit_ui/features/location/data/orbit_location_repository.dart';
import 'package:orbit_ui/features/orbit/domain/models/orbit_models.dart';
import 'package:orbit_ui/features/orbit/presentation/widgets/orbit_map_marker.dart';

void main(){
  test('authorized profile names and opaque private avatar IDs decode correctly',(){
    final marker=OrbitLocationMarker.fromJson({
      'user_id':'11111111-2222-3333-4444-555555555555',
      'latitude':31.582045,'longitude':74.329376,
      'observed_at':'2026-10-27T18:00:00Z',
      'age_seconds':5,'state':'updated','precision':'approximate',
      'display_name':'A real account',
      'avatar_media_id':'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    });
    expect(marker.displayName,'A real account');
    expect(marker.avatarMediaId,'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
    final without=OrbitLocationMarker.fromJson({
      'user_id':'11111111-2222-3333-4444-555555555555',
      'latitude':31.582045,'longitude':74.329376,
      'observed_at':'2026-10-27T18:00:00Z',
      'age_seconds':5,'state':'paused','precision':'approximate',
      'avatar_media_id':'invalid',
    });
    expect(without.avatarMediaId,isNull);
  });
  testWidgets('existing map marker receives real authorized avatar bytes', (tester) async{
    final bytes=Uint8List.fromList([1,2,3]);
    final person=OrbitPersonData(
      id:'person-1',name:'Real account',imagePath:null,
      imageBytes:bytes,markerX:0.2,markerY:0.3);
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:OrbitMapMarker(person:person,onTap:(){}))));
    final image=tester.widget<Image>(find.byType(Image));
    expect(image.image,isA<MemoryImage>());
    expect(find.text('Suzie'),findsNothing);
    // Invalid test image triggers existing Orbit initials fallback; bytes
    // remain private, never an Image.network URL.
  });
  test('realtime ticket is rejected if server does not return WSS and ephemeral token',()async{
    final repo=OrbitLocationRepository(request:(method,path,{body})async{
      expect(method,'POST');
      expect(path,'/location/realtime/ticket');
      return {'data':{'url':'http://not-wss.example.test','ticket':'short'}};
    });
    await expectLater(repo.realtimeTicket(),throwsFormatException);
  });
}
