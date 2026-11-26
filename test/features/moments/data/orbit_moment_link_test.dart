import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/navigation/orbit_moment_link.dart';

void main(){
  const id='00000000-0000-4000-8000-000000000001';
  test('HTTPS and legacy Moment references contain only the identifier',(){
    final link=OrbitMomentLink.create(id);
    expect(link.scheme,'https');
    expect(OrbitMomentLink.parse(link),id);
    expect(OrbitMomentLink.parse(Uri.parse('orbit://moment/$id')),id);
    expect(OrbitMomentLink.parse(Uri.parse('https://evil.example/moment/$id')),isNull);
    expect(OrbitMomentLink.parse(link.replace(query:'token=private')),isNull);
    expect(OrbitMomentLink.parse(Uri.parse('https://${OrbitMomentLink.host}/moment/invalid')),isNull);
  });
}
