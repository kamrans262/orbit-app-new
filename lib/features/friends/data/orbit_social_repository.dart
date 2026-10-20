import '../../auth/data/orbit_identity_client.dart';

/// M4 typed boundary: person preview never invents location, presence,
/// Circle membership, photos or favorite state which backend does not return.
class OrbitPerson {
  const OrbitPerson({
    required this.id,
    required this.name,
    required this.username,
    this.relationship = 'none',
  });
  final String id;
  final String name;
  final String username;
  final String relationship;

  factory OrbitPerson.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) throw const FormatException('Invalid person ID');
    final displayName = (json['display_name'] as String?)?.trim() ?? '';
    final username = (json['username'] as String?)?.trim() ?? '';
    return OrbitPerson(
      id: id,
      name: displayName.isNotEmpty ? displayName : (username.isEmpty ? 'Orbit user' : username),
      username: username,
      relationship: json['relationship'] as String? ?? 'none',
    );
  }
}

class OrbitFriendRequest {
  const OrbitFriendRequest({required this.id, required this.person});
  final String id;
  final OrbitPerson person;

  factory OrbitFriendRequest.fromJson(Map<String, dynamic> json) {
    final person = json['person'];
    if (person is! Map) throw const FormatException('Missing request person');
    return OrbitFriendRequest(
      id: json['id'] as String,
      person: OrbitPerson.fromJson(Map<String, dynamic>.from(person)),
    );
  }
}

class OrbitFriendPage<T> {
  const OrbitFriendPage({
    required this.items, required this.page, required this.hasMore,
    this.revision = 0,
  });
  final List<T> items;
  final int page;
  final bool hasMore;
  final int revision;
}

/// Feature-first repository; delegates *all* network/auth errors centrally.
class OrbitSocialRepository {
  OrbitSocialRepository({OrbitIdentityClient? identity})
      : _identity = identity ?? OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, Object?>? body}) async {
    final json = await _identity.socialRequest(method, path, body: body);
    final payload = json['data'];
    if (payload is! Map) throw const FormatException('Invalid social API response');
    return Map<String, dynamic>.from(payload);
  }

  OrbitFriendPage<T> _page<T>(Map<String, dynamic> json,
      T Function(Map<String, dynamic>) parse) {
    final rows = json['items'];
    if (rows is! List) throw const FormatException('Invalid social page');
    return OrbitFriendPage<T>(
      items: rows.map((row) => parse(Map<String, dynamic>.from(row as Map))).toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['has_more'] == true,
      revision: (json['revision'] as num?)?.toInt() ?? 0,
    );
  }

  Future<OrbitFriendPage<OrbitPerson>> friends({int page = 1}) async =>
      _page(await _request('GET', '/friends?page=$page'), OrbitPerson.fromJson);

  Future<OrbitFriendPage<OrbitFriendRequest>> requests(String direction,
      {int page = 1}) async {
    if (direction != 'incoming' && direction != 'outgoing') {
      throw ArgumentError.value(direction, 'direction');
    }
    return _page(await _request('GET', '/friends/requests?direction=$direction&page=$page'),
        OrbitFriendRequest.fromJson);
  }

  Future<OrbitFriendPage<OrbitPerson>> search(String query, {int page = 1}) async {
    final search = query.trim();
    if (search.length < 2) {
      return OrbitFriendPage<OrbitPerson>(items: const [], page: page, hasMore: false);
    }
    return _page(await _request('GET',
        '/people/search?q=${Uri.encodeQueryComponent(search)}&page=$page'),
        OrbitPerson.fromJson);
  }

  Future<OrbitPerson> preview(String userId) async =>
      OrbitPerson.fromJson(await _request('GET', '/people/${Uri.encodeComponent(userId)}/preview'));

  Future<void> sendRequest(String id) async {
    await _request('POST', '/friends/requests', body: {'recipient_id': id});
  }

  Future<void> respond(String requestId, String action) async {
    if (!const {'accept','decline','cancel'}.contains(action)) throw ArgumentError.value(action);
    await _request('POST', '/friends/requests/${Uri.encodeComponent(requestId)}/$action');
  }

  Future<void> removeFriend(String id) async {
    await _request('DELETE', '/friends/${Uri.encodeComponent(id)}');
  }

  Future<OrbitFriendPage<OrbitPerson>> blocks({int page = 1}) async =>
      _page(await _request('GET', '/me/blocks?page=$page'), OrbitPerson.fromJson);

  Future<void> block(String id) async {
    await _request('POST', '/me/blocks', body: {'user_id': id});
  }

  Future<void> unblock(String id) async {
    await _request('DELETE', '/me/blocks/${Uri.encodeComponent(id)}');
  }

  Future<Map<String, dynamic>> discoverySettings() => _request('GET', '/me/social/discovery');
  Future<Map<String, dynamic>> updateDiscovery(Map<String, Object?> values) =>
      _request('PATCH', '/me/social/discovery', body: values);

  Future<Map<String, dynamic>> createInvite() => _request('POST', '/friends/invites');
  /// Only redeem codes hosted by our official Orbit invitation origin.
  /// The user may paste either the private code or the shared invite URL.
  String invitationCode(String input) {
    final value = input.trim();
    if (RegExp(r'^[A-Za-z0-9_-]{43}

  /// The backend does not read the device's address book. The user must
  /// explicitly select/provide contacts; never upload without consent.
  Future<List<OrbitPerson>> matchContacts(List<Map<String, String>> contacts) async {
    final data = await _request('POST', '/people/contacts/match', body: {
      'consent_confirmed': true,
      'contacts': contacts.map((c) => <String, Object?>{
        'type': c['type'], 'value': c['value'],
      }).toList(),
    });
    final rows = data['items'] as List<dynamic>? ?? [];
    return rows.map((r) => OrbitPerson.fromJson(
      Map<String, dynamic>.from((r as Map)['person'] as Map))).toList(growable: false);
  }
}
).hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' ||
        uri.host != 'indigo-caribou-178970.hostingersite.com' ||
        uri.pathSegments.length != 3 || uri.pathSegments[0] != 'invite' ||
        uri.pathSegments[1] != 'friend' ||
        !RegExp(r'^[A-Za-z0-9_-]{43}

  /// The backend does not read the device's address book. The user must
  /// explicitly select/provide contacts; never upload without consent.
  Future<List<OrbitPerson>> matchContacts(List<Map<String, String>> contacts) async {
    final data = await _request('POST', '/people/contacts/match', body: {
      'consent_confirmed': true,
      'contacts': contacts.map((c) => <String, Object?>{
        'type': c['type'], 'value': c['value'],
      }).toList(),
    });
    final rows = data['items'] as List<dynamic>? ?? [];
    return rows.map((r) => OrbitPerson.fromJson(
      Map<String, dynamic>.from((r as Map)['person'] as Map))).toList(growable: false);
  }
}
).hasMatch(uri.pathSegments[2])) {
      throw const FormatException('Invalid Orbit invitation code.');
    }
    return uri.pathSegments[2];
  }

  Future<void> redeemInvite(String input) async {
    await _request('POST', '/friends/invites/redeem',
        body: {'invite_code': invitationCode(input)});
  }
  Future<Map<String, dynamic>> previewInvite(String input) =>
      _request('POST', '/friends/invites/preview',
          body: {'invite_code': invitationCode(input)});

  /// The backend does not read the device's address book. The user must
  /// explicitly select/provide contacts; never upload without consent.
  Future<List<OrbitPerson>> matchContacts(List<Map<String, String>> contacts) async {
    final data = await _request('POST', '/people/contacts/match', body: {
      'consent_confirmed': true,
      'contacts': contacts.map((c) => <String, Object?>{
        'type': c['type'], 'value': c['value'],
      }).toList(),
    });
    final rows = data['items'] as List<dynamic>? ?? [];
    return rows.map((r) => OrbitPerson.fromJson(
      Map<String, dynamic>.from((r as Map)['person'] as Map))).toList(growable: false);
  }
}
