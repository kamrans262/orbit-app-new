import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/orbit_searchable_header.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../../home/domain/models/home_models.dart';
import '../../../home/presentation/widgets/favorite_person_tile.dart';
import '../../data/orbit_social_repository.dart';
import 'orbit_person_screen.dart';
import 'orbit_discovery_preferences_screen.dart';

class OrbitDiscoverFriendsScreen extends StatefulWidget {
  const OrbitDiscoverFriendsScreen({super.key, this.repository});
  final OrbitSocialRepository? repository;
  @override
  State<OrbitDiscoverFriendsScreen> createState() => _OrbitDiscoverFriendsScreenState();
}

class _OrbitDiscoverFriendsScreenState extends State<OrbitDiscoverFriendsScreen> {
  late final OrbitSocialRepository _repo = widget.repository ?? OrbitSocialRepository();
  final OrbitSearchController _search = OrbitSearchController();
  Timer? _debounce;
  List<OrbitPerson> _results = const [];
  String _query = '';
  String? _error;
  bool _loading = false;
  bool _hasMore = false;
  int _page = 0;
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    final next = value.trim();
    setState(() { _query = next; _results = const []; _hasMore = false; _error = null; });
    final serial = ++_generation;
    if (next.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 350),
        () => _load(serial, reset: true));
    }
  }

  Future<void> _load(int serial, {bool reset = false}) async {
    if (!mounted || serial != _generation || _query.length < 2 ||
        (_loading && !reset)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _repo.search(_query, page: reset ? 1 : _page + 1);
      if (!mounted || serial != _generation) return;
      setState(() {
        final next = reset ? <OrbitPerson>[] : List<OrbitPerson>.of(_results);
        final known = next.map((e) => e.id).toSet();
        next.addAll(result.items.where((e) => known.add(e.id)));
        _results = next;
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (mounted && serial == _generation) {
        setState(() => _error = 'Search is unavailable. Please reconnect and retry.');
      }
    } finally {
      if (mounted && serial == _generation) { setState(() => _loading = false); }
    }
  }

  Future<void> _person(OrbitPerson person) async {
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder: (_) => OrbitPersonScreen(person: person, repository: _repo)));
    if (mounted && _query.length >= 2) _load(++_generation, reset: true);
  }

  Future<String?> _ask(String title, String hint) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          title: Text(title),
          content: TextField(controller: controller, autofocus: true,
            autocorrect: false, decoration: InputDecoration(hintText: hint)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Continue')),
          ],
        ));
    } finally { controller.dispose(); }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _link() async {
    try {
      final data = await _repo.createInvite();
      final url = data['invite_url'] as String?;
      if (url != null && mounted) await Share.share(url, subject: 'Orbit friend invitation');
    } catch (_) {
      if (mounted) _notice('Could not create an invitation. Try again.');
    }
  }

  Future<void> _redeem() async {
    final code = await _ask('Enter invitation code', 'Paste the private code');
    if (code == null || code.isEmpty) return;
    try {
      await _repo.redeemInvite(code);
      if (mounted) _notice('Friend request sent.');
    } catch (_) {
      if (mounted) _notice('Invitation unavailable, expired or already used.');
    }
  }

  Future<void> _matchContact() async {
    final contact = await _ask('Find a contact', 'Email or international phone');
    if (contact == null || contact.isEmpty || !mounted) return;
    final permission = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Match this contact?'),
        content: const Text('Only this contact will be sent to Orbit to find opted-in users. Your address book is not uploaded or stored. You can search names instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Check')),
        ]));
    if (permission != true) return;
    try {
      final people = await _repo.matchContacts([{
        'type': contact.contains('@') ? 'email' : 'phone',
        'value': contact,
      }]);
      if (!mounted) return;
      if (people.isEmpty) {
        _notice('No opted-in contact found. Try name search.');
      } else {
        await _person(people.first);
      }
    } catch (_) {
      if (mounted) _notice('Contact lookup failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20,20,20,12),
          child: OrbitSearchableHeader(
            title: 'Find Friends',
            placeholder: 'Search by name or username',
            controller: _search,
            onQueryChanged: _onQuery,
            onBack: () => Navigator.of(context).maybePop(),
            trailingActions: <Widget>[
              IconButton(
                icon: const Icon(Icons.manage_accounts_outlined),
                tooltip: 'Friend discovery settings',
                onPressed: () => Navigator.of(context).push<void>(
                  AppFadeSlidePageRoute<void>(builder: (_) =>
                    OrbitDiscoveryPreferencesScreen(repository:_repo))),
              ),
            ],
          )),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal:20,vertical:8),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (_query.isEmpty) ...[
              AppActionRow(
                leadingIcon: Icons.link_outlined,
                iconBackgroundColor: const Color(0xFFF2EAFE),
                leadingIconColor: const Color(0xFF7C3AED),
                title: 'Invite by Link', onTap: _link),
              const SizedBox(height:10),
              AppActionRow(
                leadingIcon: Icons.qr_code_scanner_outlined,
                iconBackgroundColor: const Color(0xFFF2EAFE),
                leadingIconColor: const Color(0xFF7C3AED),
                title: 'Enter Invite Code', onTap: _redeem),
              const SizedBox(height:10),
              AppActionRow(
                leadingIcon: Icons.contacts_outlined,
                iconBackgroundColor: const Color(0xFFF2EAFE),
                leadingIconColor: const Color(0xFF7C3AED),
                title: 'Find by Contact (optional)', onTap: _matchContact),
              const SizedBox(height:20),
              const Text('You can search by name without sharing contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize:13,color:Color(0xFF64748B))),
            ] else if (_query.length < 2)
              const Padding(padding:EdgeInsets.all(16),
                child: Text('Enter at least two characters.')),
            if (_loading) const Center(child: Padding(
              padding: EdgeInsets.all(18), child: CircularProgressIndicator())),
            if (_error != null) ...[
              Text(_error!,textAlign:TextAlign.center),
              TextButton(onPressed: () => _load(_generation,reset:true),
                child: const Text('Try again')),
            ],
            if (!_loading && _error == null && _query.length >= 2 && _results.isEmpty)
              const Padding(padding: EdgeInsets.all(18),
                child: Text('No matching people found.',textAlign:TextAlign.center)),
            for (final person in _results) ...[
              FavoritePersonTile(
                data: FavoritePersonData(
                  id: person.id, name: person.name,
                  status: person.username.isEmpty ? 'Orbit user' : '@${person.username}',
                  imagePath: '',isFavorite:false),
                onTap: () => _person(person),onFavoritePressed: () {},
                showFavoriteAction: false),
              const SizedBox(height:10),
            ],
            if (_hasMore) Center(child: TextButton(
              onPressed: _loading ? null : () => _load(_generation),
              child: const Text('Load more'))),
          ],
        )),
      ])),
    );
  }
}
