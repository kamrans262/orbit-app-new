import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/friends/data/orbit_social_repository.dart';

class _FakeIdentity extends OrbitIdentityClient {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> results = {};
  String? errorPath;

  @override
  Future<Map<String, dynamic>> socialRequest(String method, String path,
      {Map<String, Object?>? body}) async {
    calls.add('$method $path');
    if (path == errorPath) throw OrbitIdentityException('Server unavailable.',503);
    return results[path] ?? {'data': {'items': <Object>[], 'page':1,'has_more':false}};
  }
}

void main() {
  test('Friends and request pages parse only verified server fields', () async {
    final client = _FakeIdentity();
    client.results['/friends?page=1'] = {
      'data': {
        'items': [
          {'id':'user-a', 'display_name':'Ayesha', 'username':'ayesha',
            'relationship':'friend','private_location':{'lat':42}},
        ],
        'page':1,'has_more':true,'revision':8,
      },
    };
    client.results['/friends/requests?direction=incoming&page=1'] = {
      'data': {
        'items':[{'id':'req-1','status':'pending',
          'person':{'id':'user-b','display_name':'Omar','username':'omar'}}],
        'page':1,'has_more':false,'revision':9,
      },
    };
    final repo = OrbitSocialRepository(identity:client);
    final friends = await repo.friends();
    expect(friends.items.single.name, 'Ayesha');
    expect(friends.items.single.username, 'ayesha');
    expect(friends.items.single.relationship, 'friend');
    expect(friends.items.single.id,'user-a');
    expect(friends.hasMore, true);
    expect(friends.revision,8);
    final pending = await repo.requests('incoming');
    expect(pending.items.single.id,'req-1');
    expect(pending.items.single.person.name,'Omar');
    expect(() => repo.requests('other'), throwsArgumentError);
  });

  test('Name/username finder safely escapes query and refuses short queries', () async {
    final client = _FakeIdentity();
    final repo = OrbitSocialRepository(identity:client);
    final empty = await repo.search('a');
    expect(empty.items,isEmpty);
    expect(client.calls,isEmpty);
    await repo.search('Fatima Noor');
    expect(client.calls.single,
      'GET /people/search?q=Fatima+Noor&page=1');
  });

  test('Block, request and contact APIs preserve authenticated transport methods', () async {
    final client = _FakeIdentity();
    final repo = OrbitSocialRepository(identity:client);
    await repo.sendRequest('user-1');
    await repo.respond('req-1','accept');
    await repo.respond('req-2','cancel');
    await repo.block('user-1');
    await repo.unblock('user-1');
    expect(client.calls,[
      'POST /friends/requests',
      'POST /friends/requests/req-1/accept',
      'POST /friends/requests/req-2/cancel',
      'POST /me/blocks',
      'DELETE /me/blocks/user-1',
    ]);
    expect(() => repo.respond('req-2','approve'),throwsArgumentError);
  });

  test('Invitation URL parsing accepts only official host and 43-character tokens', () {
    final repo = OrbitSocialRepository(identity: _FakeIdentity());
    const code = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    expect(repo.invitationCode(code),code);
    expect(repo.invitationCode('https://indigo-caribou-178970.hostingersite.com/invite/friend/$code'),code);
    expect(() => repo.invitationCode('https://example.com/invite/friend/$code'),
        throwsFormatException);
    expect(() => repo.invitationCode('not-a-code'),throwsFormatException);
  });

  test('Network failure does not manufacture friend lists or mark block successful', () async {
    final client = _FakeIdentity();
    client.errorPath = '/friends?page=1';
    final repo = OrbitSocialRepository(identity:client);
    await expectLater(repo.friends(),throwsA(isA<OrbitIdentityException>()));
  });

  test('Invalid server payload fails closed rather than loading sample people', () async {
    final client = _FakeIdentity();
    client.results['/friends?page=1'] = {'data': 'invalid'};
    final repo = OrbitSocialRepository(identity:client);
    await expectLater(repo.friends(),throwsFormatException);
  });
}
