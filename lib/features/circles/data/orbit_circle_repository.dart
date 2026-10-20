import '../../auth/data/orbit_identity_client.dart';

/// M5 server-authoritative Circle. The API never provides live presence,
/// avatars, location, group-chat access or automatic sharing permissions.
class OrbitCircle {
  const OrbitCircle({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.role,
    required this.memberCount,
    required this.revision,
    this.iconKey,
    this.colorValue,
    this.capabilities = const <String, bool>{},
  });
  final String id;
  final String name;
  final String ownerId;
  final String role;
  final int memberCount;
  final int revision;
  final String? iconKey;
  final String? colorValue;
  final Map<String, bool> capabilities;

  bool can(String key) => capabilities[key] == true;
  factory OrbitCircle.fromJson(Map<String, dynamic> data) {
    final id = data['id'], name = data['name'];
    if (id is! String || id.isEmpty || name is! String) {
      throw const FormatException('Invalid Circle response.');
    }
    final rawCaps = data['capabilities'];
    return OrbitCircle(
      id: id, name: name, ownerId: data['owner_id'] as String? ?? '',
      role: data['role'] as String? ?? 'member',
      memberCount: (data['member_count'] as num?)?.toInt() ?? 0,
      revision: (data['revision'] as num?)?.toInt() ?? 0,
      iconKey: data['icon_key'] as String?, colorValue: data['color_value'] as String?,
      capabilities: rawCaps is Map ? rawCaps.map((k, v) =>
        MapEntry(k.toString(), v == true)) : const <String, bool>{},
    );
  }
}

class OrbitCircleMember {
  const OrbitCircleMember({required this.id, required this.name,
    required this.username, required this.role});
  final String id, name, username, role;
  factory OrbitCircleMember.fromJson(Map<String, dynamic> data) =>
      OrbitCircleMember(
        id: data['id'] as String,
        name: data['display_name'] as String? ?? 'Orbit user',
        username: data['username'] as String? ?? '',
        role: data['role'] as String? ?? 'member',
      );
}

class OrbitCircleInvite {
  const OrbitCircleInvite({
    required this.id, required this.status,
    this.person, this.circleId, this.circleName, this.code, this.createdAt,
  });
  final String id, status;
  final OrbitCircleMember? person;
  final String? circleId, circleName, code;
  final DateTime? createdAt;

  factory OrbitCircleInvite.fromJson(Map<String, dynamic> data) {
    final p = data['person'];
    return OrbitCircleInvite(
      id: data['id'] as String,
      status: data['status'] as String? ?? 'pending',
      person: p is Map ? OrbitCircleMember.fromJson(
        {...Map<String, dynamic>.from(p), 'role': 'member'}) : null,
      circleId: data['circle_id'] as String?,
      circleName: data['circle_name'] as String?,
      code: data['code'] as String?,
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? ''),
    );
  }
}

class OrbitCirclePage<T> {
  const OrbitCirclePage(this.items, this.page, this.hasMore);
  final List<T> items;
  final int page;
  final bool hasMore;
}

/// M5 reuses the M4 trusted-session HTTP stack, retry, timeouts and errors.
/// Never cache raw invite codes, roster, access grants or sensitive metadata.
class OrbitCircleRepository {
  OrbitCircleRepository({OrbitIdentityClient? identity})
      : _identity = identity ?? OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, Object?>? body}) async {
    final payload = await _identity.socialRequest(method, path, body: body);
    final data = payload['data'];
    if (data is! Map) throw const FormatException('Invalid Circle API payload.');
    return Map<String, dynamic>.from(data);
  }

  String _segment(String id) => Uri.encodeComponent(id);
  OrbitCirclePage<T> _page<T>(Map<String, dynamic> data,
      T Function(Map<String, dynamic>) parse) {
    final raw = data['items'];
    if (raw is! List) throw const FormatException('Invalid Circle page.');
    return OrbitCirclePage<T>(
      raw.map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      (data['page'] as num?)?.toInt() ?? 1,
      data['has_more'] == true,
    );
  }

  Future<OrbitCirclePage<OrbitCircle>> list({int page = 1}) async =>
      _page(await _request('GET','/circles?page=$page'), OrbitCircle.fromJson);

  Future<OrbitCircle> detail(String id) async =>
      OrbitCircle.fromJson(await _request('GET','/circles/${_segment(id)}'));

  Future<OrbitCircle> create(String name, {String? color, String? icon}) async =>
      OrbitCircle.fromJson(await _request('POST','/circles', body: {
        'name': name.trim(), if (color != null) 'color_value': color,
        if (icon != null) 'icon_key': icon,
      }));

  Future<OrbitCircle> update(String id, {String? name, String? color}) async =>
      OrbitCircle.fromJson(await _request('PATCH','/circles/${_segment(id)}', body: {
        if (name != null) 'name': name.trim(),
        if (color != null) 'color_value': color,
      }));

  Future<OrbitCirclePage<OrbitCircleMember>> members(String id,
      {int page = 1}) async =>
      _page(await _request('GET','/circles/${_segment(id)}/members?page=$page'),
          OrbitCircleMember.fromJson);

  Future<OrbitCirclePage<OrbitCircleInvite>> outgoing(String id,
      {int page = 1}) async =>
      _page(await _request('GET','/circles/${_segment(id)}/invites?page=$page'),
          OrbitCircleInvite.fromJson);

  Future<OrbitCirclePage<OrbitCircleInvite>> incoming({int page = 1}) async =>
      _page(await _request('GET','/circles/invites/incoming?page=$page'),
          OrbitCircleInvite.fromJson);

  Future<OrbitCircleInvite> invite(String circleId, String personId) async =>
      OrbitCircleInvite.fromJson(await _request('POST',
        '/circles/${_segment(circleId)}/invites', body: {'invitee_id': personId}));

  Future<void> answer(String inviteId, {required bool accept}) async {
    await _request('POST','/circles/invites/${_segment(inviteId)}/${accept ? 'accept' : 'decline'}');
  }

  Future<void> revoke(String circleId, String inviteId) async {
    await _request('DELETE','/circles/${_segment(circleId)}/invites/${_segment(inviteId)}');
  }

  /// The backend accepts raw 40-character recipient-bound codes only.
  /// Official invite URLs may be parsed but arbitrary hosts are never trusted.
  String validateCode(String input) {
    var code = input.trim();
    final uri = Uri.tryParse(code);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'https' ||
          uri.host != 'indigo-caribou-178970.hostingersite.com' ||
          uri.pathSegments.length != 3 || uri.pathSegments[0] != 'invite' ||
          uri.pathSegments[1] != 'circle' || uri.hasQuery || uri.hasFragment) {
        throw const FormatException('Invalid Orbit Circle invitation link.');
      }
      code = uri.pathSegments.last;
    }
    if (!RegExp(r'^[A-Za-z0-9]{40}$').hasMatch(code)) {
      throw const FormatException('Enter a valid Circle invitation code.');
    }
    return code;
  }

  Future<Map<String, dynamic>> previewCode(String input) =>
      _request('POST','/circles/invites/code/preview',
        body: {'code': validateCode(input)});

  Future<void> redeemCode(String input) async {
    await _request('POST','/circles/invites/code/redeem',
      body: {'code': validateCode(input), 'confirmation': 'JOIN'});
  }

  Future<void> leave(String id) async {
    await _request('POST','/circles/${_segment(id)}/leave');
  }

  Future<void> remove(String circle, String member) async {
    await _request('DELETE','/circles/${_segment(circle)}/members/${_segment(member)}');
  }

  Future<void> changeRole(String circle, String member, String role) async {
    await _request('PATCH','/circles/${_segment(circle)}/members/${_segment(member)}',
      body: {'role': role});
  }

  Future<void> transferOwner(String circle, String member) async {
    await _request('POST','/circles/${_segment(circle)}/ownership-transfer',
      body: {'recipient_id': member, 'confirmation':'TRANSFER'});
  }

  Future<void> archive(String circle) async {
    await _request('POST','/circles/${_segment(circle)}/archive',
      body: {'confirmation': 'ARCHIVE'});
  }

  Future<void> restore(String circle) async {
    await _request('POST','/circles/${_segment(circle)}/restore',
      body: {'confirmation': 'RESTORE'});
  }

  Future<OrbitCirclePage<OrbitCircle>> archived({int page = 1}) async =>
      _page(await _request('GET','/circles/archived?page=$page'), OrbitCircle.fromJson);

  Future<Map<String, dynamic>> primary() => _request('GET','/me/circles/primary');
  Future<void> choosePrimary(String? id) async {
    await _request('PUT','/me/circles/primary', body: {'circle_id': id});
  }

  Future<Map<String, dynamic>> permissions(String id) =>
      _request('GET','/circles/${_segment(id)}/permissions');
}
