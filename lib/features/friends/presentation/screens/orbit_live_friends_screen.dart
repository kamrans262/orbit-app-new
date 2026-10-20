import 'package:flutter/material.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../circles/domain/models/friend_details_models.dart';
import '../../data/orbit_social_repository.dart';
import 'friends_screen.dart';
import 'orbit_discover_friends_screen.dart';
import 'orbit_friend_requests_screen.dart';
import 'orbit_person_screen.dart';

/// Authenticated entry point. Never substitute Figma demo users for API data.
class OrbitLiveFriendsScreen extends StatefulWidget {
  const OrbitLiveFriendsScreen({super.key, this.repository});
  final OrbitSocialRepository? repository;

  @override
  State<OrbitLiveFriendsScreen> createState() => _OrbitLiveFriendsScreenState();
}

class _OrbitLiveFriendsScreenState extends State<OrbitLiveFriendsScreen> {
  late final OrbitSocialRepository _repo = widget.repository ?? OrbitSocialRepository();
  final List<OrbitPerson> _people = [];
  bool _busy = false;
  bool _hasMore = false;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final page = await _repo.friends(page: reset ? 1 : _page + 1);
      if (!mounted) return;
      setState(() {
        if (reset) _people.clear();
        final known = _people.map((p) => p.id).toSet();
        _people.addAll(page.items.where((p) => known.add(p.id)));
        _hasMore = page.hasMore;
        _page = page.page;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Friends could not be loaded. Please reconnect and try again.'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _go(Widget screen) async {
    await Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(builder: (_) => screen));
    if (mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return FriendsScreen(
      liveMode: true,
      friends: _people.map((person) => FriendMemberData(
        id: person.id,
        name: person.name,
        status: person.username.isEmpty ? 'Orbit friend' : '@${person.username}',
        imagePath: null,
      )).toList(growable: false),
      isLoading: _busy,
      errorMessage: _error,
      onRetry: () => _load(reset: true),
      hasMore: _hasMore,
      onLoadMore: () => _load(),
      onBack: () => Navigator.of(context).maybePop(),
      onDiscover: () => _go(OrbitDiscoverFriendsScreen(repository: _repo)),
      onRequests: () => _go(OrbitFriendRequestsScreen(repository: _repo)),
      onFriendPressed: (friend) {
        final person = _people.where((p) => p.id == friend.id).first;
        _go(OrbitPersonScreen(person: person, repository: _repo));
      },
    );
  }
}
