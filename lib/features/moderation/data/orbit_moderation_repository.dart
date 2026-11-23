import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../profile/domain/models/report_user_models.dart';

/// M17 transport reads only authenticated, owner-private receipts. No client
/// access exists for moderator cases, reporter identities, E2EE contents or
/// other people's sanctions.
class OrbitModerationRepository {
  OrbitModerationRepository({
    OrbitIdentityClient? identity,
    OrbitModerationPendingVault? pending,
  })  : _identity = identity ?? OrbitIdentityClient.instance,
        _pending = pending ?? OrbitModerationPendingVault();

  final OrbitIdentityClient _identity;
  final OrbitModerationPendingVault _pending;
  static const Uuid _uuid = Uuid();

  Future<String> owner() async {
    final id = await _identity.currentLocalSocialOwner();
    if (id == null || id.isEmpty) {
      throw OrbitIdentityException('Sign in to report an account.', 401);
    }
    return id;
  }

  Future<Object?> _call(String method, String path,
      {Map<String, Object?>? body}) async {
    final initialOwner = await owner();
    final response = await _identity.socialRequest(method, path, body: body);
    if (await _identity.currentLocalSocialOwner() != initialOwner) {
      await _pending.clearAll();
      throw OrbitIdentityException('Your Orbit account has changed.', 401);
    }
    if (!response.containsKey('data')) {
      throw const FormatException('Invalid moderation response.');
    }
    return response['data'];
  }

  Future<Map<String, dynamic>> _object(String method, String path,
      {Map<String, Object?>? body}) async {
    final data = await _call(method, path, body: body);
    if (data is! Map) {
      throw const FormatException('Invalid moderation response.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final data = await _call('GET', path);
    if (data is! List) {
      throw const FormatException('Invalid moderation listing.');
    }
    return data.map((value) {
      if (value is! Map) {
        throw const FormatException('Invalid moderation entry.');
      }
      return Map<String, dynamic>.from(value);
    }).toList(growable: false);
  }

  Future<OrbitModerationReceipt> submitReport(ReportRequest request) async {
    final actor = await owner();
    final body = <String, Object?>{
      'target_kind': 'account',
      'target_id': request.reportedUserId,
      'reason': request.reason.apiValue,
      if (request.additionalDetails != null &&
          request.additionalDetails!.trim().isNotEmpty)
        'additional_details': request.additionalDetails!.trim(),
    };
    final pending = await _pending.read(actor, 'report');
    // A timeout is unknown, not success. A conscious retry with the same
    // request reuses the exact persisted client_id and payload.
    final clientId = pending != null && _sameBody(pending.body, body)
        ? pending.clientId
        : _uuid.v4();
    final intent = OrbitModerationIntent(
      owner: actor,
      kind: 'report',
      clientId: clientId,
      createdAt: DateTime.now().toUtc(),
      body: body,
    );
    await _pending.put(intent);
    try {
      final json = await _object('POST', '/moderation/reports',
          body: <String, Object?>{...body, 'client_id': clientId});
      final receipt = OrbitModerationReceipt.fromJson(json);
      await _pending.clear('report');
      return receipt;
    } on OrbitIdentityException catch (error) {
      // A definitive 4xx is not an uncertain post-commit timeout.
      if (error.statusCode != null &&
          error.statusCode! >= 400 && error.statusCode! < 500 &&
          error.statusCode != 429) {
        await _pending.clear('report');
      }
      rethrow;
    }
  }

  Future<OrbitModerationReceipt> reportReceipt(String id) async =>
      OrbitModerationReceipt.fromJson(await _object('GET',
          '/moderation/reports/${Uri.encodeComponent(id)}'));

  Future<List<OrbitModerationReceipt>> myReports() async {
    final items = await _list('/me/moderation/reports');
    return items.map(OrbitModerationReceipt.fromJson).toList(growable: false);
  }

  Future<List<OrbitModerationAction>> myActions() async {
    final items = await _list('/me/moderation/actions');
    return items.map(OrbitModerationAction.fromJson).toList(growable: false);
  }

  Future<List<OrbitModerationAppeal>> myAppeals() async {
    final items = await _list('/me/moderation/appeals');
    return items.map(OrbitModerationAppeal.fromJson).toList(growable: false);
  }

  /// Atomic view-model ownership, not atomic server reads. Never mix
  /// reports from a previous account with a new account's sanctions.
  Future<OrbitModerationHistorySnapshot> myHistory() async {
    final actor = await owner();
    final reports = await myReports();
    final actions = await myActions();
    final appeals = await myAppeals();
    if (await owner() != actor) {
      throw OrbitIdentityException('Your Orbit account has changed.', 401);
    }
    return OrbitModerationHistorySnapshot(
      reports: reports, actions: actions, appeals: appeals,
    );
  }

  Future<OrbitModerationAppeal> appeal(String actionId,
      {String? statement}) async {
    final actor = await owner();
    final body = <String, Object?>{
      if (statement != null && statement.trim().isNotEmpty)
        'statement': statement.trim(),
    };
    final pending = await _pending.read(actor, 'appeal');
    final clientId = pending != null &&
            pending.subjectId == actionId &&
            _sameBody(pending.body, body)
        ? pending.clientId
        : _uuid.v4();
    await _pending.put(OrbitModerationIntent(
      owner: actor,
      kind: 'appeal',
      subjectId: actionId,
      clientId: clientId,
      createdAt: DateTime.now().toUtc(),
      body: body,
    ));
    try {
      final data = await _object('POST',
        '/moderation/actions/${Uri.encodeComponent(actionId)}/appeals',
        body: <String, Object?>{...body, 'client_id': clientId});
      final receipt = OrbitModerationAppeal.fromJson(data);
      await _pending.clear('appeal');
      return receipt;
    } on OrbitIdentityException catch(error) {
      if (error.statusCode != null &&
          error.statusCode! >= 400 && error.statusCode! < 500 &&
          error.statusCode != 429) {
        await _pending.clear('appeal');
      }
      rethrow;
    }
  }

  static bool _sameBody(Map<String, Object?> a, Map<String, Object?> b) =>
      jsonEncode(a) == jsonEncode(b);
}

class OrbitModerationHistorySnapshot {
  const OrbitModerationHistorySnapshot({
    required this.reports, required this.actions, required this.appeals,
  });
  final List<OrbitModerationReceipt> reports;
  final List<OrbitModerationAction> actions;
  final List<OrbitModerationAppeal> appeals;
}

class OrbitModerationReceipt {
  const OrbitModerationReceipt({
    required this.id, required this.status, required this.createdAt,
  });
  final String id;
  final String status;
  final DateTime createdAt;
  factory OrbitModerationReceipt.fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final status = data['status'];
    final date = DateTime.tryParse(data['created_at'] as String? ?? '');
    if (id is! String || id.isEmpty ||
        status != 'received' || date == null) {
      throw const FormatException('Unconfirmed moderation report.');
    }
    return OrbitModerationReceipt(id: id, status: status, createdAt: date);
  }
}

class OrbitModerationAction {
  const OrbitModerationAction({
    required this.id, required this.scope, required this.status,
    required this.createdAt, this.endsAt,
  });
  final String id, scope, status;
  final DateTime createdAt;
  final DateTime? endsAt;

  /// The original M13 restriction automatically expires. The audit row stays
  /// 'active' as recorded, but must never be represented as an active block
  /// once its exact server-authoritative expiry has passed.
  String get effectiveStatus {
    if (status == 'active' && scope == 'messaging_send' &&
        endsAt != null && !DateTime.now().toUtc().isBefore(endsAt!.toUtc())) {
      return 'expired';
    }
    return status;
  }

  factory OrbitModerationAction.fromJson(Map<String, dynamic> data) {
    final id = data['id'], scope = data['scope'], status = data['status'];
    final date = DateTime.tryParse(data['created_at'] as String? ?? '');
    final endRaw = data['ends_at'];
    final end = endRaw == null ? null : DateTime.tryParse(endRaw as String);
    if (id is! String || id.isEmpty ||
        !['warning','messaging_send'].contains(scope) ||
        !['active','reversed'].contains(status) ||
        date == null || (endRaw != null && end == null)) {
      throw const FormatException('Invalid moderation action.');
    }
    return OrbitModerationAction(
      id: id, scope: scope as String, status: status as String,
      createdAt: date, endsAt: end,
    );
  }
}

class OrbitModerationAppeal {
  const OrbitModerationAppeal({
    required this.id, required this.status, required this.createdAt,
    this.decisionCode, this.decidedAt, this.actionId,
  });
  final String id, status;
  final String? actionId;
  final DateTime createdAt;
  final String? decisionCode;
  final DateTime? decidedAt;
  factory OrbitModerationAppeal.fromJson(Map<String, dynamic> data) {
    final id = data['id'], status = data['status'];
    final date = DateTime.tryParse(data['created_at'] as String? ?? '');
    if (id is! String || id.isEmpty ||
        !['pending','upheld','reversed'].contains(status) || date == null) {
      throw const FormatException('Invalid appeal response.');
    }
    return OrbitModerationAppeal(
      id: id, status: status as String, createdAt: date,
      actionId: data['action_id'] as String?,
      decisionCode: data['decision_code'] as String?,
      decidedAt: DateTime.tryParse(data['decided_at'] as String? ?? ''),
    );
  }
}

/// Only a short-lived, owner-bound retry token and a user-selected payload.
/// Stored in the platform secure store, never in preferences or push data.
/// There is NO automatic background report/appeal upload.
class OrbitModerationIntent {
  const OrbitModerationIntent({
    required this.owner, required this.kind, required this.clientId,
    required this.createdAt, required this.body, this.subjectId,
  });
  final String owner, kind, clientId;
  final String? subjectId;
  final DateTime createdAt;
  final Map<String, Object?> body;
  Map<String, Object?> toJson() => <String, Object?>{
    'owner': owner, 'kind': kind, 'client_id': clientId,
    'subject_id': subjectId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'body': body,
  };
  factory OrbitModerationIntent.fromJson(Map<String, dynamic> data) =>
      OrbitModerationIntent(
        owner: data['owner'] as String,
        kind: data['kind'] as String,
        clientId: data['client_id'] as String,
        subjectId: data['subject_id'] as String?,
        createdAt: DateTime.parse(data['created_at'] as String),
        body: Map<String, Object?>.from(data['body'] as Map),
      );
}

class OrbitModerationPendingVault {
  OrbitModerationPendingVault({FlutterSecureStorage? storage}) :
      _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const Duration maxAge = Duration(hours: 24);
  static String _key(String kind) => 'orbit.m17.pending.v1.$kind';

  Future<void> put(OrbitModerationIntent intent) =>
      _storage.write(key: _key(intent.kind), value: jsonEncode(intent.toJson()));

  Future<OrbitModerationIntent?> read(String owner, String kind) async {
    final raw = await _storage.read(key: _key(kind));
    if (raw == null) return null;
    try {
      final intent = OrbitModerationIntent.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
      final age = DateTime.now().toUtc().difference(intent.createdAt.toUtc());
      if (intent.owner == owner && intent.kind == kind &&
          age >= Duration.zero && age <= maxAge) {
        return intent;
      }
    } catch (_) { /* Malformed sensitive entries are discarded. */ }
    await clear(kind);
    return null;
  }

  Future<void> clear(String kind) => _storage.delete(key: _key(kind));
  Future<void> clearAll() async {
    await clear('report');
    await clear('appeal');
  }
}
