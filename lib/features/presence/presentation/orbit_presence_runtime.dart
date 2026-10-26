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
  OrbitPresenceRuntime({OrbitPresenceRepository? repository, OrbitPresenceSocket? socket,
    DateTime Function()? clock})
      : _repository=repository ?? OrbitPresenceRepository(),
        _socket=socket ?? OrbitPresenceSocket(repository:repository),
        _now=clock ?? DateTime.now;

  static final instance=OrbitPresenceRuntime();

  final OrbitPresenceRepository _repository;
  final OrbitPresenceSocket _socket;
  final DateTime Function() _now;
  final Map<String, OrbitPresenceSnapshot> _circles={};
  final Map<String,int> _circleVersions={};
  final Set<String> _refreshing=<String>{};
  final Set<String> _watches={};
  final Map<String,Set<String>> _watchOwners={};
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _heartbeat;
  Timer? _expiry;
  Timer? _revalidation;
  bool _active=false;
  bool _started=false;
  DateTime _lastInteraction=DateTime.now();
  String _lastPublishedState='active';
  bool _beating=false;
  bool _freshBeatQueued=false;
  int _epoch=0;

  bool get started => _started;
  bool get socketReady => _socket.connected;

  Future<void> start() async {
    if (!OrbitPresenceRollout.enabled || _started) return;
    _started=true;
    _active=true;
    _lastInteraction=_now();
    _lastPublishedState='active';
    final epoch=++_epoch;
    WidgetsBinding.instance.addObserver(this);
    _events=_socket.events.listen(_onEvent);
    _heartbeat=Timer.periodic(const Duration(seconds:25), (_) {
      if (_started && _active) unawaited(_beat());
    });
    _expiry=Timer.periodic(const Duration(seconds:5), (_) {
      if (_active && _watches.isNotEmpty && _circles.isNotEmpty) notifyListeners();
    });
    // UI freshness check, not a substitute for the M9 WebSocket gateway.
    _revalidation=Timer.periodic(const Duration(seconds:20),
      (_) => unawaited(refreshWatched()));
    await _beat();
    if (epoch==_epoch && _started && _active) {
      unawaited(_socket.connect());
    }
  }

  /// Only on a user interaction inside authenticated Orbit Home. Background
  /// and network activity alone must never masquerade as user activity.
  void recordActivity() {
    if (!_started || !_active) return;
    _lastInteraction=_now();
    if (_lastPublishedState=='idle') {
      if (_beating) {
        // Never lose a return-to-active signal during an in-flight idle beat.
        _freshBeatQueued=true;
      } else {
        unawaited(_beat());
      }
    }
  }

  /// Refreshes current server-scoped snapshots before the 30s UI expiry.
  /// Also useful after a transport reconnection; never uses cached history.
  Future<void> refreshWatched() async {
    if (!_active || !_started) return;
    final pending=<Future<void>>[];
    for (final id in _watches.toList()) {
      if (_refreshing.add(id)) {
        pending.add(refresh(id).whenComplete(() => _refreshing.remove(id)));
      }
    }
    await Future.wait(pending);
  }

  Future<void> heartbeatNow() => _beat();

  Future<void> _beat() async {
    if (!_started || !_active || _beating) return;
    _beating=true;
    final epoch=_epoch;
    final state=_now().difference(_lastInteraction)
        >= const Duration(seconds:60) ? 'idle':'active';
    try {
      await _repository.heartbeat(state);
      if (_started && _active && epoch==_epoch) {
        _lastPublishedState=state;
        // A user may have interacted while the idle network call was pending.
        if (state=='idle' && _now().difference(_lastInteraction)
            < const Duration(seconds:60)) _freshBeatQueued=true;
      }
    } on OrbitIdentityException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403 ||
          error.statusCode == 404 || error.statusCode == 409) {
        await stop();
      } else {
        clear();
      }
    } catch (_) {
      clear();
    } finally {
      _beating=false;
      final retry=_freshBeatQueued && _started && _active && epoch==_epoch;
      _freshBeatQueued=false;
      if (retry) unawaited(_beat());
    }
  }

  Future<void> watch(String circle, {String source='circle-detail'}) async {
    if (!_started || !_active) return;
    final sources=_watchOwners.putIfAbsent(circle,()=><String>{});
    if (!sources.add(source)) return; // no repeated polling on Home refresh
    _watches.add(circle);
    await refresh(circle);
  }

  void unwatch(String circle, {String source='circle-detail'}) {
    final sources=_watchOwners[circle];
    if (sources==null || !sources.remove(source)) return;
    if (sources.isNotEmpty) return; // other authenticated screen still needs it
    _watchOwners.remove(circle);
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
      if (snapshot.circleId!=circle) {
        throw const FormatException('Presence response Circle mismatch.');
      }
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

  /// Only among server-authorized per-Circle snapshots currently watched.
  OrbitPresenceMember? memberInCircles(Iterable<String> circles, String person,
      {DateTime? now}) {
    if (!_started || !_active) return null;
    final stamp=now ?? DateTime.now();
    OrbitPresenceMember? idle;
    for (final circle in circles) {
      final value=member(circle,person,now:stamp);
      if (value?.state=='active_now') return value;
      idle ??= value;
    }
    return idle;
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
    // Include pending reads, not only cached Circles. A previous in-flight
    // response must never restore state after Ghost, background or sign-out.
    for (final id in _watches) {
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
      _lastInteraction=_now();
      unawaited(_beat());
      unawaited(_socket.connect());
      for (final id in _watches.toList()) { unawaited(refresh(id)); }
    } else {
      _active=false;
      ++_epoch;
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
    _lastPublishedState='active';
    _freshBeatQueued=false;
    _heartbeat?.cancel(); _heartbeat=null;
    _expiry?.cancel(); _expiry=null;
    _revalidation?.cancel(); _revalidation=null;
    WidgetsBinding.instance.removeObserver(this);
    final events=_events; _events=null;
    await events?.cancel();
    _watches.clear();
    _watchOwners.clear();
    _refreshing.clear();
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
  Widget build(BuildContext context)=>OrbitPresenceRollout.enabled
      ? Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => OrbitPresenceRuntime.instance.recordActivity(),
          onPointerMove: (_) => OrbitPresenceRuntime.instance.recordActivity(),
          child: widget.child,
        )
      : widget.child;
}
