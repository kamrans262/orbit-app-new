import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'orbit_circle_change_source.dart';

/// Firebase RTDB is present in code but stays COMPLETELY INERT unless the
/// build opts in AND the trusted Laravel backend returns an approved ticket.
///
/// The stream carries ONLY Circle UUID and revision. Backend GETs authorize
/// all actual Circle content after EVERY notification. The Firebase SDK
/// must never serve cached membership/location/chat as authoritative data.
class OrbitM5FirebaseChangeSource extends OrbitCircleChangeSource {
  OrbitM5FirebaseChangeSource._();

  static final OrbitM5FirebaseChangeSource instance =
      OrbitM5FirebaseChangeSource._();

  static const bool compiledEnabled =
      bool.fromEnvironment('ORBIT_M5_FIREBASE_ENABLED', defaultValue: false);

  final StreamController<OrbitCircleInvalidation> _changes =
      StreamController<OrbitCircleInvalidation>.broadcast();
  final Map<String, StreamSubscription<DatabaseEvent>> _watches = {};
  final Map<String, int> _revisions = {};
  Future<Map<String, dynamic>> Function()? _requestTicket;
  Future<void>? _connecting;
  FirebaseAuth? _auth;
  FirebaseDatabase? _database;
  int _identityEpoch = 0;

  @override
  Stream<OrbitCircleInvalidation> get invalidations => _changes.stream;

  /// Called with the existing OrbitIdentityClient-backed repository.
  void setBootstrap(Future<Map<String, dynamic>> Function() bootstrap) {
    _requestTicket = bootstrap;
  }

  Future<void> _connect() async {
    if (!compiledEnabled || _database != null || _requestTicket == null) {
      return;
    }
    if (_connecting != null) return _connecting!;
    final task = _establishConnection();
    _connecting = task;
    try {
      await task;
    } finally {
      _connecting = null;
    }
  }

  Future<void> _establishConnection() async {
    final epoch = _identityEpoch;
    final data = await _requestTicket!();
    if (epoch != _identityEpoch) return;
    if (data['enabled'] != true || data['custom_token'] is! String ||
        data['firebase'] is! Map) {
      return; // Server policy denies; polling stays active.
    }
    final options = Map<String, dynamic>.from(data['firebase'] as Map);
    String field(String key) {
      final value = options[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Firebase configuration unavailable.');
      }
      return value;
    }

    final id = field('project_id');
    final url = field('database_url');
    if (!url.startsWith('https://') ||
        !(url.endsWith('.firebaseio.com') ||
          url.endsWith('.firebasedatabase.app'))) {
      throw const FormatException('Invalid Firebase origin.');
    }
    final app = Firebase.apps.where((app) => app.name == 'orbit-m5-realtime')
        .firstOrNull ??
        await Firebase.initializeApp(
          name: 'orbit-m5-realtime',
          options: FirebaseOptions(
            apiKey: field('api_key'),
            appId: field('app_id'),
            messagingSenderId: field('sender_id'),
            projectId: id,
            databaseURL: url,
          ),
        );
    final auth = FirebaseAuth.instanceFor(app: app);
    // This secondary app is isolated from Orbit's own trusted-device auth.
    await auth.signInWithCustomToken(data['custom_token'] as String);
    if (epoch != _identityEpoch) {
      await auth.signOut();
      return;
    }
    _auth = auth;
    _database = FirebaseDatabase.instanceFor(app: app, databaseURL: url);
  }

  /// Only active, authenticated screens should subscribe. No-op by default.
  Future<void> watchCircles(Iterable<String> ids) async {
    if (!compiledEnabled) return;
    try {
      await _connect();
      final db = _database;
      if (db == null) return;
      for (final id in ids.toSet()) {
        if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
            _watches.containsKey(id)) {
          continue;
        }
        _watches[id] = db.ref('orbit_m5/revisions/$id').onValue.listen(
          (event) {
            final raw = event.snapshot.value;
            if (raw is! num) return;
            final revision = raw.toInt();
            final old = _revisions[id];
            if (old != null && revision <= old) return;
            _revisions[id] = revision;
            _changes.add(OrbitCircleInvalidation(
              circleId: id, revision: revision,
            ));
          },
          onError: (Object _) {
            // A removed/blocked member can lose Firebase .read permission.
            // Don't trust an old cached revision: refresh the Orbit ACL now.
            _changes.add(OrbitCircleInvalidation(circleId: id, revision: 0));
            unawaited(_watches.remove(id)?.cancel());
            _revisions.remove(id);
          },
          cancelOnError: true,
        );
      }
    } catch (_) {
      // Not provisioned, revoked, offline or wrong project: no Firebase
      // fallback data is displayed; 25-second authenticated HTTP polling
      // remains the only state source.
    }
  }

  /// Auth logout, identity switch, or account deletion invalidates all hooks.
  Future<void> stop() async {
    // Invalidates any still-in-flight HTTP ticket or Firebase sign-in.
    _identityEpoch++;
    final watching = _watches.values.toList();
    _watches.clear();
    _revisions.clear();
    _requestTicket = null;
    _database = null;
    for (final subscription in watching) {
      await subscription.cancel();
    }
    final auth = _auth;
    _auth = null;
    if (auth != null) {
      try {
        await auth.signOut();
      } catch (_) {
        // A local sign-out failure never restores the Orbit session.
      }
    }
  }
}
