import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_circle_repository.dart';
import '../../data/orbit_circle_snapshot.dart';
import '../../domain/models/friend_details_models.dart';
import 'circle_list_screen.dart';
import 'orbit_live_circle_detail_screen.dart';
import 'orbit_live_create_circle_screen.dart';
import 'orbit_circle_qr_scan_screen.dart';
import 'orbit_live_archived_circles_screen.dart';

/// Real account-bound M5 Circles surface. No M4 demo Circle identifiers
/// or fake membership/presence/location values ever reach this screen.
class OrbitLiveCirclesScreen extends StatefulWidget {
  const OrbitLiveCirclesScreen({super.key, this.repository, this.store,
    this.initialInviteCode});
  final OrbitCircleRepository? repository;
  final OrbitCircleSnapshotStore? store;
  final String? initialInviteCode;

  @override
  State<OrbitLiveCirclesScreen> createState() => _OrbitLiveCirclesScreenState();
}

class _OrbitLiveCirclesScreenState extends State<OrbitLiveCirclesScreen>
    with WidgetsBindingObserver {
  late final OrbitCircleRepository _repo = widget.repository ?? OrbitCircleRepository();
  late final OrbitCircleSnapshotStore _store = widget.store ?? OrbitCircleSnapshotStore();
  List<OrbitCircle> _circles = const [];
  bool _busy = true, _offline = false;
  String? _error;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load().then((_) {
      if (!mounted || widget.initialInviteCode == null) return;
      if (!_offline && !_busy && _error == null) {
        _join(widget.initialInviteCode!);
      }
    });
  }

  @override
  void dispose() {
    _serial++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  bool _networkError(Object e) =>
      e is OrbitIdentityException &&
      (e.statusCode == null || e.statusCode! >= 500);

  Future<void> _load() async {
    final current = ++_serial;
    if (mounted) setState(() {_busy = true; _error = null;});
    try {
      final items = <OrbitCircle>[];
      for (var page = 1; page <= 20; page++) {
        final result = await _repo.list(page: page);
        items.addAll(result.items);
        if (!result.hasMore) break;
      }
      if (!mounted || current != _serial) return;
      setState(() {
        _circles = items;
        _offline = false;
        _busy = false;
      });
      try { await _store.save(items); } catch (_) {}
    } catch (error) {
      if (!mounted || current != _serial) return;
      if (_networkError(error)) {
        OrbitCircleSnapshot? cached;
        try { cached = await _store.read(); } catch (_) {}
        if (!mounted || current != _serial) return;
        setState(() {
          _circles = cached?.circles ?? const [];
          _offline = cached != null;
          _error = cached == null
            ? 'Unable to verify Circles. Reconnect and try again.' : null;
          _busy = false;
        });
      } else {
        try { await _store.clear(); } catch (_) {}
        if (!mounted || current != _serial) return;
        setState(() {
          _circles = const [];
          _offline = false;
          _error = error is OrbitIdentityException && error.statusCode == 404
            ? 'Circles are not enabled on the server yet.'
            : 'Circle access could not be verified. Sign in again or retry.';
          _busy = false;
        });
      }
    }
  }

  void _notify(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _create() async {
    if (_offline || _busy) return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder: (_) => OrbitLiveCreateCircleScreen(repository: _repo)));
    if (mounted) await _load();
  }

  Future<void> _open(OrbitCircle circle) async {
    if (_offline) return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder: (_) => OrbitLiveCircleDetailScreen(
        circleId: circle.id, repository: _repo)));
    if (mounted) await _load();
  }

  Future<void> _join(String code) async {
    if (_offline || _busy) return;
    try {
      final preview = await _repo.previewCode(code);
      if (!mounted) return;
      final answer = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Join Circle?', style: TextStyle(
            fontFamily: AppTypography.fontFamily)),
          content: Text('Join ${preview['circle_name']}? You will not share '
            'your location, presence or Moments by joining.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(d, true),
              child: const Text('Join Circle')),
          ],
        ),
      );
      if (answer != true) return;
      await _repo.redeemCode(code);
      if (!mounted) return;
      _notify('You joined the Circle.');
      await _load();
    } catch (e) {
      _notify(e is OrbitIdentityException ? e.message :
        e is FormatException ? e.message : 'Unable to join this Circle.');
    }
  }

  Future<void> _scan() async {
    if(_offline || _busy) return;
    final code = await Navigator.of(context).push<String>(
      AppFadeSlidePageRoute<String>(
        builder:(_) => OrbitCircleQrScanScreen(repository:_repo),
      ),
    );
    if(mounted && code != null) await _join(code);
  }

  Future<void> _archived() async {
    if(_offline || _busy)return;
    await Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder:(_)=>OrbitLiveArchivedCirclesScreen(repository:_repo),
      ),
    );
    if(mounted) await _load();
  }

  Future<void> _incoming() async {
    if (_offline || _busy) return;
    try {
      final result = await _repo.incoming();
      if (!mounted) return;
      if (result.items.isEmpty) {
        _notify('You have no pending Circle invitations.');
        return;
      }
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true,
        backgroundColor: AppColors.background,
        builder: (sheet) => SafeArea(child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(shrinkWrap: true, children: [
            const Text('Circle invitations', style: TextStyle(
              fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w600, fontSize: 20)),
            for (final invite in result.items)
              ListTile(
                title: Text(invite.circleName ?? 'Circle'),
                subtitle: const Text('Invitation pending'),
                trailing: Wrap(spacing: 5, children: [
                  IconButton(icon: const Icon(Icons.close),
                    tooltip: 'Decline', onPressed: () async {
                      try {
                        await _repo.answer(invite.id,accept:false);
                        if (sheet.mounted) Navigator.pop(sheet);
                        if (mounted) await _load();
                      } catch (_) { if (mounted) _notify('Unable to decline invitation.'); }
                    }),
                  IconButton(icon: const Icon(Icons.check),
                    tooltip: 'Accept', onPressed: () async {
                      try {
                        await _repo.answer(invite.id,accept:true);
                        if (sheet.mounted) Navigator.pop(sheet);
                        if (mounted) await _load();
                      } catch (_) { if (mounted) _notify('Unable to accept invitation.'); }
                    }),
                ]),
              ),
          ]),
        )),
      );
    } catch (e) {
      _notify(e is OrbitIdentityException ? e.message : 'Unable to load invitations.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(child: Column(children: [
    if (_offline)
      Container(
        color: const Color(0xFFFFF0E7),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: const Text('OFFLINE — READ ONLY. Cached Circle names may be stale. '
          'Reconnect to view members or make changes.',
          style: TextStyle(fontFamily: AppTypography.fontFamily,fontSize:12)),
      ),
    if (!_offline && !_busy)
      SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[
          TextButton.icon(onPressed:_scan,
            icon:const Icon(Icons.qr_code_scanner),label:const Text('Scan QR')),
          TextButton.icon(onPressed:_incoming,
            icon:const Icon(Icons.mail_outline),label:const Text('Invitations')),
          TextButton.icon(onPressed:_archived,
            icon:const Icon(Icons.archive_outlined),label:const Text('Archived')),
        ]),
      ),
    Expanded(child: CircleListScreen(
      circles: _circles.map((circle) => CircleGroupData(
        id: circle.id, name: circle.name,
        memberCount: _offline ? 0 : circle.memberCount,
        memberAvatars: const <String?>[],
      )).toList(growable: false),
      viewState: _busy ? CircleListViewState.loading
        : _error != null ? CircleListViewState.error : CircleListViewState.loaded,
      errorMessage: _error ?? 'Circles are unavailable.',
      onRetry: _load,
      onBack: () => Navigator.of(context).maybePop(),
      // Server does not support favorites; do not fabricate persistent favorite.
      enableFavoriteControls: false,
      showMemberCounts: !_offline,
      onCreatePressed: _offline || _busy ? () => _notify('Reconnect to create a Circle.') : _create,
      onJoinRequested: _offline || _busy ? (_) => _notify('Reconnect to join a Circle.') : _join,
      onCirclePressed: _offline ? (_) => _notify('Reconnect to view Circle members.')
        : (c) => _open(_circles.firstWhere((x) => x.id == c.id)),
    )),
  ])),
  );
}
