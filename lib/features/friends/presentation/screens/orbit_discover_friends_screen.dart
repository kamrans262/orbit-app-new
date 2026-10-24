import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/orbit_searchable_header.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/popups/orbit_popup_modal.dart';
import '../widgets/orbit_social_confirmation.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../../home/domain/models/home_models.dart';
import '../../../home/presentation/widgets/favorite_person_tile.dart';
import '../../data/orbit_social_repository.dart';
import '../../data/orbit_contact_picker.dart';
import 'orbit_person_screen.dart';
import 'orbit_friend_qr_scan_screen.dart';
import 'orbit_discovery_preferences_screen.dart';

class OrbitDiscoverFriendsScreen extends StatefulWidget {
  const OrbitDiscoverFriendsScreen({super.key, this.repository, this.initialInviteCode});
  final OrbitSocialRepository? repository;
  final String? initialInviteCode;
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
  void initState() {
    super.initState();
    final initial = widget.initialInviteCode;
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _previewAndRedeem(initial);
      });
    }
  }

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

  Future<String?> _ask(String title, String hint) =>
      showOrbitPopupModal<String>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _OrbitInviteEntryPopup(title: title, hint: hint),
      );

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _link() async {
    try {
      final data = await _repo.createInvite();
      final url = data['invite_url'] as String?;
      if (url == null || !mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Friend Invitation', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Scan this QR code or share the private link. It can only be redeemed once and expires in seven days.'),
              const SizedBox(height: 20),
              Center(child: QrImageView(data: url, version: QrVersions.auto,
                size: 220, backgroundColor: Colors.white)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async => Share.share(url, subject: 'Orbit friend invitation'),
                icon: const Icon(Icons.ios_share), label: const Text('Share invitation')),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      );
    } catch (_) {
      if (mounted) _notice('Could not create an invitation. Try again.');
    }
  }


  Future<void> _previewAndRedeem(String tokenOrLink) async {
    try {
      final code = _repo.invitationCode(tokenOrLink);
      final data = await _repo.previewInvite(code);
      if (!mounted) return;
      final who = data['display_name'] as String? ??
          data['username'] as String? ?? 'this person';
      final accepted = await confirmOrbitSocialAction(
        context,
        title: 'Friend invitation',
        description: 'Send a friend request to $who? This does not grant location or Circle access.',
        confirmation: 'Send request',
      
      );
      if (accepted != true) return;
      await _repo.redeemInvite(code);
      if (mounted) _notice('Friend request sent.');
    } catch (_) {
      if (mounted) _notice('Invitation unavailable, expired or already used.');
    }
  }

  Future<void> _redeem() async {
    final code = await _ask('Enter invitation code', 'Paste code or Orbit link');
    if (code == null || code.isEmpty) return;
    await _previewAndRedeem(code);
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(
      AppFadeSlidePageRoute<String>(builder: (_) =>
        OrbitFriendQrScanScreen(repository: _repo)),
    );
    if (!mounted || code == null) return;
    await _previewAndRedeem(code);
  }

  Future<void> _matchSelected(String type, String value) async {
    if (!mounted) return;
    final accepted = await confirmOrbitSocialAction(
      context,
      title: 'Match this contact?',
      description: 'Only the one selected address or number will be checked against people who opted in. Orbit will not upload your address book.',
      confirmation: 'Find friend',
      
    );
    if (accepted != true) return;
    try {
      final matches = await _repo.matchContacts([
        {'type': type, 'value': value},
      ]);
      if (!mounted) return;
      if (matches.isEmpty) {
        _notice('No opted-in contact matched. Search by name instead.');
      } else {
        await _person(matches.first);
      }
    } catch (_) {
      if (mounted) _notice('Contact matching failed. You can search by name.');
    }
  }

  Future<void> _pickContact() async {
    try {
      final choice = await OrbitContactPicker().pick();
      if (!mounted) return;
      if (choice == null) {
        _notice('No eligible contact selected. You can search by name or enter a contact manually.');
        return;
      }
      await _matchSelected(choice.type, choice.value);
    } catch (_) {
      if (mounted) _notice('Contacts permission unavailable. Manual search still works.');
    }
  }

  Future<void> _matchContact() async {
    final contact = await _ask('Find a contact', 'Email or +country-code phone');
    if (contact == null || contact.isEmpty) return;
    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(contact);
    final phone = contact.replaceAll(RegExp(r'[\s().-]'), '');
    final validPhone = RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone);
    if (!validEmail && !validPhone) {
      if (mounted) _notice('Enter a valid email or international phone number.');
      return;
    }
    await _matchSelected(validEmail ? 'email' : 'phone',
        validEmail ? contact.trim().toLowerCase() : phone);
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
              AppCircularIconButton(
                semanticLabel: 'Friend discovery settings',
                icon: Icons.manage_accounts_outlined,
                iconSize: 20,
                iconColor: const Color(0xFF7C3AED),
                size: 40,
                onPressed: () => Navigator.of(context).push<void>(
                  AppFadeSlidePageRoute<void>(builder: (_) =>
                    OrbitDiscoveryPreferencesScreen(repository: _repo))),
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
                leadingIcon: Icons.qr_code_scanner_outlined,
                iconBackgroundColor: const Color(0xFFF2EAFE),
                leadingIconColor: const Color(0xFF7C3AED),
                title: 'Scan Invite QR', onTap: _scanQr),
              const SizedBox(height:10),
              AppActionRow(
                leadingIcon: Icons.contact_page_outlined,
                iconBackgroundColor: const Color(0xFFF2EAFE),
                leadingIconColor: const Color(0xFF7C3AED),
                title: 'Select Contact (optional)', onTap: _pickContact),
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

 
/// Owns the text controller for the full lifetime of the popup's outgoing
/// transition. Disposing in _ask() after pop() is too early for showGeneralDialog.
class _OrbitInviteEntryPopup extends StatefulWidget {
  const _OrbitInviteEntryPopup({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<_OrbitInviteEntryPopup> createState() => _OrbitInviteEntryPopupState();
}

class _OrbitInviteEntryPopupState extends State<_OrbitInviteEntryPopup> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbitPopupModal(
        title: widget.title,
        showCloseButton: true,
        content: AppTextField(
          controller: _controller,
          hintText: widget.hint,
          textInputAction: TextInputAction.done,
        ),
        primaryAction: OrbitPopupPrimaryButton(
          label: 'Continue',
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
        secondaryAction: OrbitPopupTextButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
}
