import 'package:flutter/material.dart';

import '../../../friends/data/orbit_social_repository.dart';
import '../../domain/models/user_privacy_entry.dart';
import 'blocked_users_screen.dart';

/// Production blocked-user list. Does not show or infer demonstration users.
class OrbitLiveBlockedUsersScreen extends StatefulWidget {
  const OrbitLiveBlockedUsersScreen({super.key, this.repository});
  final OrbitSocialRepository? repository;
  @override
  State<OrbitLiveBlockedUsersScreen> createState() => _OrbitLiveBlockedUsersScreenState();
}

class _OrbitLiveBlockedUsersScreenState extends State<OrbitLiveBlockedUsersScreen> {
  late final OrbitSocialRepository _repo = widget.repository ?? OrbitSocialRepository();
  List<UserPrivacyEntry> _users = const [];
  bool _loading = false;
  bool _hasMore = false;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load(reset:true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.blocks(page: reset ? 1 : _page + 1);
      if (!mounted) return;
      setState(() {
        final list = reset ? <UserPrivacyEntry>[] : List<UserPrivacyEntry>.of(_users);
        final known = list.map((e) => e.id).toSet();
        for (final person in data.items) {
          if (known.add(person.id)) {
            list.add(UserPrivacyEntry(
              id: person.id, name: person.name, avatarUrl:'', isBlocked:true));
          }
        }
        _users = list;
        _hasMore = data.hasMore;
        _page = data.page;
      });
    } catch (_) {
      if (mounted) setState(() =>
        _error = 'Blocked accounts could not be loaded. Please reconnect.');
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _unblock(UserPrivacyEntry user) async {
    await _repo.unblock(user.id);
    if (mounted) await _load(reset:true);
  }

  @override
  Widget build(BuildContext context) {
    return BlockUsersScreen(
      liveMode:true,
      users:_users,
      isLoading:_loading && _users.isEmpty,
      errorMessage:_error,
      onRetry:()=>_load(reset:true),
      onUnblockRequested:_unblock,
      onBack:()=>Navigator.of(context).maybePop(),
      hasMore:_hasMore,
      isLoadingMore:_loading,
      onLoadMore:()=>_load(),
    );
  }
}
