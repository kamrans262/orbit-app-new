import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../circles/domain/models/friend_details_models.dart';
import '../../data/orbit_friend_snapshot.dart';
import '../../data/orbit_social_repository.dart';
import 'friends_screen.dart';
import 'orbit_discover_friends_screen.dart';
import 'orbit_friend_requests_screen.dart';
import 'orbit_person_screen.dart';

class OrbitLiveFriendsScreen extends StatefulWidget {
  const OrbitLiveFriendsScreen({super.key, this.repository, this.snapshotStore});
  final OrbitSocialRepository? repository;
  final OrbitFriendSnapshotStore? snapshotStore;
  @override
  State<OrbitLiveFriendsScreen> createState() => _OrbitLiveFriendsScreenState();
}

class _OrbitLiveFriendsScreenState extends State<OrbitLiveFriendsScreen>
    with WidgetsBindingObserver {
  late final OrbitSocialRepository _repo = widget.repository ?? OrbitSocialRepository();
  late final OrbitFriendSnapshotStore _store = widget.snapshotStore ?? OrbitFriendSnapshotStore();
  final List<OrbitPerson> _people = [];
  Timer? _revisionTimer;
  bool _busy = false, _hasMore = false, _offline = false;
  String? _error;
  int _page = 0, _revision = 0, _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(reset: true);
    _revisionTimer = Timer.periodic(const Duration(seconds: 25), (_) => _checkRevision());
  }
  @override
  void dispose() {
    _epoch++;
    _revisionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkRevision();
  }
  bool _outage(Object e) => e is OrbitIdentityException &&
      (e.statusCode == null || e.statusCode! >= 500);

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    final epoch = ++_epoch;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _repo.friends(page: reset ? 1 : _page + 1);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        if (reset) _people.clear();
        final known = _people.map((p) => p.id).toSet();
        _people.addAll(result.items.where((p) => known.add(p.id)));
        _hasMore = result.hasMore;
        _page = result.page;
        _revision = result.revision;
        _offline = false;
      });
      // A storage/Keychain error must never turn a successfully loaded
      // server-authorized Friends list into a false network failure.
      try { await _store.save(_people); } catch (_) {}
    } catch (failure) {
      if (!mounted || epoch != _epoch) return;
      if (_outage(failure)) {
        OrbitFriendSnapshot? cached;
        try { cached = await _store.read(); } catch (_) { cached = null; }
        if (!mounted || epoch != _epoch) return;
        setState(() {
          _people..clear()..addAll(cached?.people ?? const <OrbitPerson>[]);
          _offline = cached != null;
          _hasMore = false;
          _error = cached == null
              ? 'Friends unavailable. Reconnect to verify your session.'
              : null;
        });
      } else {
        await _store.clear();
        if (!mounted || epoch != _epoch) return;
        setState(() {
          _people.clear();
          _hasMore = false;
          _offline = false;
          _error = 'Your permissions could not be verified. Sign in again.';
        });
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _checkRevision() async {
    if (_busy || _offline || !mounted) return;
    try {
      final revision = await _repo.currentRevision();
      if (!mounted || _busy) return;
      if (revision != _revision) {
        setState(() { _people.clear(); _hasMore = false; });
        await _store.clear();
        await _load(reset: true);
      }
    } on OrbitIdentityException catch (failure) {
      if (!mounted) return;
      if (failure.statusCode != null && failure.statusCode! < 500) {
        await _store.clear();
        if (!mounted) return;
        setState(() {
          _people.clear();
          _hasMore = false;
          _error = 'Your session permissions changed. Sign in again.';
        });
      }
    } catch (_) {
      // Foreground retry still validates current server authorization.
    }
  }

  Future<void> _go(Widget screen) async {
    if (_offline) return;
    await Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(builder: (_) => screen));
    if (mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => FriendsScreen(
    liveMode: true, offlineStale: _offline,
    friends: _people.map((p) => FriendMemberData(
      id: p.id, name: p.name,
      status: p.username.isEmpty ? 'Orbit friend' : '@' + p.username,
      imagePath: null,
    )).toList(growable: false),
    isLoading: _busy, errorMessage: _error,
    onRetry: () => _load(reset: true),
    hasMore: !_offline && _hasMore,
    onLoadMore: _offline ? null : () => _load(),
    onBack: () => Navigator.of(context).maybePop(),
    onDiscover: _offline ? null : () => _go(OrbitDiscoverFriendsScreen(repository: _repo)),
    onRequests: _offline ? null : () => _go(OrbitFriendRequestsScreen(repository: _repo)),
    onFriendPressed: _offline ? null : (f) =>
      _go(OrbitPersonScreen(person: _people.firstWhere((p) => p.id == f.id), repository: _repo)),
  );
}
