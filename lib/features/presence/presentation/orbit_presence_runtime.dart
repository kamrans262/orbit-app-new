import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../data/orbit_presence_models.dart';
import '../data/orbit_presence_repository.dart';
import '../data/orbit_presence_rollout.dart';
import '../data/orbit_presence_socket.dart';

/// Single in-memory Presence coordinator. It never persists a status or
/// tries to infer online from M8 Home, device last_seen, or friends snapshots.
class OrbitPresenceRuntime extends ChangeNotifier with WidgetsBindingObserver {
  OrbitPresenceRuntime({OrbitPresenceRepository? repository, OrbitPresenceSocket? socket})
      : _repository=repository ?? OrbitPresenceRepository(),
        _socket=socket ?? OrbitPresenceSocket(repository:repository);

  static final instance=OrbitPresenceRuntime();

  final OrbitPresenceRepository _repository;
  final OrbitPresenceSocket _socket;
  final Map<String, OrbitPresenceSnapshot> _circles={};
  final Map<String,int> _circleVersions={};
  final Set<String> _watches={};
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _heartbeat;
  Timer? _expiry;
  bool _active=false;
  bool _started=false;
  int _epoch=0;

  bool get started => _started;
  bool get socketReady => _socket.connected;

  Future<void> start() async {
    if (!OrbitPresenceRollout.enabled || _started) return;
    _started=true;
    _active=true;
    final epoch=++_epoch;
    WidgetsBinding.instance.addObserver(this);
    _events=_socket.events.listen(_onEvent);
    _heartbeat=Timer.periodic(const Duration(seconds:40), (_) {
      if (_started && _active) unawaited(_beat());
    });
    _expiry=Timer.periodic(const Duration(seconds:3), (_) => notifyListeners());
    await _beat();
    if (epoch==_epoch && _started && _active) {
      unawaited(_socket.connect());
    }
  }

  Future<void> _beat() async {
    if (!_started || !_active) return;
    try {
      await _repository.heartbeat('active');
    } on OrbitIdentityException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403 ||
          error.statusCode == 404 || error.statusCode == 409) {
        await stop();
      } else {
        clear();
      }
    } catch (_) {
      clear();
    }
  }

  Future<void> watch(String circle) async {
    if (!_started || !_active) return;
    _watches.add(circle);
    await refresh(circle);
  }

  void unwatch(String circle) {
    _watches.remove(circle);
    _circleVersions[circle]=(_circleVersions[circle] ?? 0)+1;
    _circles.remove(circle);
    notifyListeners();
  }

  /// The response is always a *fresh, server-authorized* Circle projection.
  Future<void> refresh(String circle) async {
    if (!_active || !_started || !_watches.contains(circle)) return;
    final epoch=_epoch;
    final revision=(_circleVersions[circle] ?? 0)+1;
    _circleVersions[circle]=revision;
    try {
      final snapshot=await _repository.circle(circle);
      if (!_started || !_active || epoch!=_epoch ||
          _circleVersions[circle]!=revision || !_watches.contains(circle)) return;
      _circles[circle]=snapshot;
      notifyListeners();
    } catch (_) {
      // Permission revoked, offline or malformed: never retain old dots.
      if (_circleVersions[circle]!=revision || epoch!=_epoch) return;
      _circles.remove(circle);
      notifyListeners();
    }
  }

  OrbitPresenceMember? member(String circle, String memberId, {DateTime? now}) {
    if (!_started || !_active) return null;
    return _circles[circle]?.member(memberId,now ?? DateTime.now());
  }

  void _onEvent(Map<String,dynamic> event) {
    final type=event['type'];
    if (type=='presence.transport_down') {
      clear();
      return;
    }
    final circle=event['circle_id'];
    if (circle is! String || !_watches.contains(circle)) return;
    // Invalidate first: even an old queued event cannot resurrect a revoked dot.
    _circleVersions[circle]=(_circleVersions[circle] ?? 0)+1;
    _circles.remove(circle);
    notifyListeners();
    if (type=='presence.changed' || type=='presence.clear') {
      unawaited(refresh(circle));
    }
    // circle_clear intentionally requires a subsequent explicit server reload.
    // Typing events do not cause an unauthorized presence indicator.
  }

  void clear() {
    if (_circles.isEmpty) return;
    for (final id in _circles.keys) {
      _circleVersions[id]=(_circleVersions[id] ?? 0)+1;
    }
    _circles.clear();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state==AppLifecycleState.resumed) {
      _active=true;
      unawaited(_beat());
      unawaited(_socket.connect());
      for (final id in _watches.toList()) { unawaited(refresh(id)); }
    } else {
      _active=false;
      clear();
      unawaited(_repository.disconnect().catchError((Object _) {}));
      unawaited(_socket.stop());
    }
  }

  Future<void> stop() async {
    if (!_started) { clear(); return; }
    _started=false;
    _active=false;
    _epoch++;
    _heartbeat?.cancel(); _heartbeat=null;
    _expiry?.cancel(); _expiry=null;
    WidgetsBinding.instance.removeObserver(this);
    final events=_events; _events=null;
    await events?.cancel();
    _watches.clear();
    clear();
    _circleVersions.clear();
    await _socket.stop();
    // Best effort only; backend lease expires in <=90s after network failure.
    try { await _repository.disconnect(); } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}

/// Attached only to a server-verified Orbit Home route.
/// Does not run on Splash, Welcome, offline Profile, or unauthenticated UI.
class OrbitPresenceLifecycle extends StatefulWidget {
  const OrbitPresenceLifecycle({required this.child,super.key});
  final Widget child;
  @override
  State<OrbitPresenceLifecycle> createState()=>_OrbitPresenceLifecycleState();
}

class _OrbitPresenceLifecycleState extends State<OrbitPresenceLifecycle> {
  @override
  void initState() {
    super.initState();
    if (OrbitPresenceRollout.enabled) {
      unawaited(OrbitPresenceRuntime.instance.start());
    }
  }
  @override
  void dispose() {
    if (OrbitPresenceRollout.enabled) {
      unawaited(OrbitPresenceRuntime.instance.stop());
    }
    super.dispose();
  }
  @override
  Widget build(BuildContext context)=>widget.child;
}
