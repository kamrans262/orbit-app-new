import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/circles/data/orbit_circle_repository.dart';

class _CaptureClient extends OrbitIdentityClient {
  final calls = <String>[];
  final payloads = <Map<String, Object?>?>[];
  final keys = <String?>[];
  @override
  Future<Map<String, dynamic>> socialRequest(String method, String path,
      {Map<String, Object?>? body, String? idempotencyKey}) async {
    calls.add('$method $path');
    payloads.add(body);
    keys.add(idempotencyKey);
    if (path.endsWith('/invites') && method == 'POST') {
      return {'data':{
        'id':'invite-1','status':'pending',
        'code':'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890ABCD',
      }};
    }
    if (path.endsWith('/permissions')) {
      return {'data':{'sharing_active':false,'grants_enabled':false}};
    }
    if (path.endsWith('/circles') && method == 'POST' ||
        path.endsWith('/circles/circle-1') && method == 'PATCH') {
      return {'data':{'id':'circle-1','name':body?['name'] ?? 'A',
        'owner_id':'user-1','role':'owner','revision':1,'member_count':1}};
    }
    if (path.contains('/primary'))return {'data':{'circle_id':'circle-1'}};
    if (path.endsWith('/circles'))return {'data':{'items':[],'page':1,'has_more':false}};
    return {'data':{'ok':true}};
  }
}

void main() {
  test('Circle creation carries stable explicit idempotency key', () async {
    final client=_CaptureClient(), repo=OrbitCircleRepository(identity:client);
    await repo.create('Family',color:'#FF00AA',icon:'star',idempotencyKey:'intent-safe-987');
    expect(client.calls.single,'POST /circles');
    expect(client.keys.single,'intent-safe-987');
    expect(client.payloads.single,{'name':'Family','color_value':'#FF00AA','icon_key':'star'});
  });
  test('Circle metadata mutation uses approved PATCH fields only', () async {
    final client=_CaptureClient(), repo=OrbitCircleRepository(identity:client);
    await repo.update('circle-1',icon:'home');
    expect(client.calls.single,'PATCH /circles/circle-1');
    expect(client.payloads.single,{'icon_key':'home'});
  });
  test('Friend invites only submit server-scoped recipient UUID field', () async {
    final client=_CaptureClient(), repo=OrbitCircleRepository(identity:client);
    final invite=await repo.invite('circle-1','person-1');
    expect(invite.code?.length,40);
    expect(client.payloads.single,{'invitee_id':'person-1'});
  });
  test('Redeem always transmits explicit JOIN confirmation; preview does not join',() async {
    final client=_CaptureClient(), repo=OrbitCircleRepository(identity:client);
    const code='ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890ABCD';
    await repo.previewCode(code);
    expect(client.calls.single,'POST /circles/invites/code/preview');
    expect(client.payloads.single,{'code':code});
    await repo.redeemCode(code);
    expect(client.calls.last,'POST /circles/invites/code/redeem');
    expect(client.payloads.last,{'code':code,'confirmation':'JOIN'});
  });
  test('Circle ownership and archive mutations always include explicit server confirmations', () async {
    final client=_CaptureClient(), repo=OrbitCircleRepository(identity:client);
    await repo.transferOwner('circle-1','person-1');
    await repo.archive('circle-1');
    await repo.restore('circle-1');
    expect(client.payloads[0],{'recipient_id':'person-1','confirmation':'TRANSFER'});
    expect(client.payloads[1],{'confirmation':'ARCHIVE'});
    expect(client.payloads[2],{'confirmation':'RESTORE'});
  });
  test('Role and remove mutations cannot affect arbitrary paths or impersonate identities',() async {
    final client=_CaptureClient(), repo=OrbitCircleRepository(identity:client);
    await repo.changeRole('circle-1','person-1','restricted');
    await repo.remove('circle-1','person-1');
    await repo.leave('circle-1');
    expect(client.calls[0],'PATCH /circles/circle-1/members/person-1');
    expect(client.payloads[0],{'role':'restricted'});
    expect(client.calls[1],'DELETE /circles/circle-1/members/person-1');
    expect(client.calls[2],'POST /circles/circle-1/leave');
  });
  test('Primary selection is an owner-scoped authenticated API call',() async {
    final client=_CaptureClient(), repo=OrbitCircleRepository(identity:client);
    await repo.choosePrimary('circle-1');
    await repo.choosePrimary(null);
    expect(client.calls,['PUT /me/circles/primary','PUT /me/circles/primary']);
    expect(client.payloads[0],{'circle_id':'circle-1'});
    expect(client.payloads[1],{'circle_id':null});
  });
  test('Revoke capability is read from backend not inferred from role',() {
    final forbidden=OrbitCircleInvite.fromJson({'id':'i1','status':'pending',
      'can_revoke':false,'person':{'id':'u1','username':'u1','display_name':'User'}});
    final permitted=OrbitCircleInvite.fromJson({'id':'i2','status':'pending',
      'can_revoke':true,'person':{'id':'u1','username':'u1','display_name':'User'}});
    expect(forbidden.canRevoke,false);
    expect(permitted.canRevoke,true);
  });
  test('Circle code refuses credential-in-URL, wrong host and insecure scheme',() {
    final repo=OrbitCircleRepository();
    const code='ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890ABCD';
    for(final invalid in [
      'http://indigo-caribou-178970.hostingersite.com/invite/circle/$code',
      'https://admin@indigo-caribou-178970.hostingersite.com/invite/circle/$code',
      'https://evil.example/invite/circle/$code',
      'https://indigo-caribou-178970.hostingersite.com:8443/invite/circle/$code',
      'https://indigo-caribou-178970.hostingersite.com/invite/friend/$code',
    ]) {
      expect(()=>repo.validateCode(invalid),throwsFormatException);
    }
  });
}
