import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../welcome/domain/models/nearby_person.dart';
import '../../../welcome/presentation/screens/invite_people_screen.dart';
import '../../../friends/data/orbit_contact_picker.dart';
import '../../../friends/presentation/widgets/orbit_social_confirmation.dart';
import '../../../../core/popups/orbit_popup_modal.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../data/orbit_circle_repository.dart';

/// Only active M4 friends can receive recipient-bound M5 Circle invites.
/// Codes are shown once and never persisted by the Flutter client.
class OrbitLiveInviteMemberScreen extends StatefulWidget {
  const OrbitLiveInviteMemberScreen({
    required this.circleId,super.key,this.repository,this.friendsRepository,
  });
  final String circleId;
  final OrbitCircleRepository? repository;
  final OrbitSocialRepository? friendsRepository;

  @override
  State<OrbitLiveInviteMemberScreen> createState()=>_OrbitLiveInviteMemberScreenState();
}

class _OrbitLiveInviteMemberScreenState extends State<OrbitLiveInviteMemberScreen> {
  late final OrbitCircleRepository _circles=widget.repository ?? OrbitCircleRepository();
  late final OrbitSocialRepository _friends=widget.friendsRepository ?? OrbitSocialRepository();
  List<OrbitPerson> _people=const [];
  final TextEditingController _searchController=TextEditingController();
  final FocusNode _searchFocus=FocusNode();
  String _query='';
  bool _loading=true,_sending=false;
  String? _error;
  DateTime? _rateLimitedUntil;
  Timer? _rateLimitTimer;

  bool get _rateLimited => _rateLimitedUntil != null &&
      DateTime.now().isBefore(_rateLimitedUntil!);

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {super.initState();_load();}
  Future<void> _load() async {
    if(mounted) setState(() {_loading=true;_error=null;});
    try {
      final people=<OrbitPerson>[];
      for(var page=1;page<=20;page++){
        final result=await _friends.friends(page:page);
        people.addAll(result.items);
        if(!result.hasMore) break;
      }
      // Filter out existing members and recipients with pending invitations.
      // The backend enforces these rules too; this prevents misleading
      // controls, not a client-side authorization bypass.
      final excluded=<String>{};
      for(var page=1;page<=20;page++){
        final result=await _circles.members(widget.circleId,page:page);
        excluded.addAll(result.items.map((member)=>member.id));
        if(!result.hasMore) break;
      }
      for(var page=1;page<=20;page++){
        final result=await _circles.outgoing(widget.circleId,page:page);
        for(final invite in result.items) {
          if(invite.status=='pending' && invite.person!=null) {
            excluded.add(invite.person!.id);
          }
        }
        if(!result.hasMore) break;
      }
      if(!mounted) return;
      setState(() {
        _people=people.where((p)=>!excluded.contains(p.id)).toList(growable:false);
        _loading=false;
      });
    } catch (_) {
      if(mounted) setState(() {
        _error='Unable to verify your friends. Reconnect and retry.';
        _loading=false;
      });
    }
  }

  Future<void> _invite(OrbitPerson person) async {
    if(_sending || _rateLimited) return;
    setState(()=>_sending=true);
    try {
      final invite=await _circles.invite(widget.circleId,person.id);
      if(!mounted) return;
      if(invite.code != null && invite.code!.isNotEmpty) {
        final code=invite.code!;
        await showOrbitPopupModal<void>(
          context:context,
          builder:(d)=>OrbitPopupModal(
            title:'Private Circle invitation',
            description:'For ${person.name} only. Valid for 7 days. '
              'Share privately; the code will be shown only once.',
            content:Column(
              mainAxisSize:MainAxisSize.min,
              children:[
                QrImageView(data:code,size:190),
                const SizedBox(height:12),
                SelectableText(code),
                const SizedBox(height:12),
                OrbitPopupTextButton(
                  label:'Share code',
                  onPressed:() async {
                    await Share.share('Private Orbit Circle invitation for ${person.name}: $code '
                      '(valid for 7 days; usable by the intended recipient only).');
                  },
                ),
              ],
            ),
            primaryAction:OrbitPopupPrimaryButton(
              label:'Copy code',
              onPressed:() async {
                await Clipboard.setData(ClipboardData(text:code));
                if(d.mounted) Navigator.of(d).pop();
              },
            ),
            secondaryAction:OrbitPopupTextButton(
              label:'Done',
              onPressed:()=>Navigator.of(d).pop(),
            ),
          ),
        );
      } else {
        _notice('Invitation sent. Awaiting acceptance.');
      }
      if(mounted) Navigator.of(context).pop();
    } catch(e) {
      if (e is OrbitIdentityException && e.statusCode == 429) {
        // Respect the backend's 10-per-minute invitation limit. No retries.
        _rateLimitedUntil = DateTime.now().add(const Duration(seconds: 65));
        _rateLimitTimer?.cancel();
        _rateLimitTimer = Timer(const Duration(seconds: 65), () {
          if (mounted) setState(() => _rateLimitedUntil = null);
        });
        if (mounted) _notice(
          'Invitation limit reached. Please try again in about a minute.');
      } else if (mounted) {
        _notice(e is OrbitIdentityException ? e.message
            : 'Unable to invite this friend.');
      }
    } finally {
      if(mounted) setState(()=>_sending=false);
    }
  }

  /// The existing Orbit popup is used instead of native SnackBars or
  /// a different modal design.
  void _notice(String message) {
    if (!mounted) return;
    showOrbitPopupModal<void>(
      context: context,
      builder: (dialog) => OrbitPopupModal(
        title: 'Circle invitation',
        description: message,
        primaryAction: OrbitPopupPrimaryButton(
          label: 'OK',
          onPressed: () => Navigator.of(dialog).pop(),
        ),
      ),
    );
  }

  void _explainRecipientBoundShare(String method) {
    _notice('Circle invitation $method is private and tied to one '
        'eligible friend. Tap + beside a friend below to create an '
        'invitation and see its one-time QR code and shareable code.');
  }

  void _findUsername() {
    _searchFocus.requestFocus();
  }

  Future<void> _pickContact() async {
    try {
      final selected = await OrbitContactPicker().pick();
      if (!mounted) return;
      if (selected == null) {
        _notice('No contact selected. You can search by username instead.');
        return;
      }
      final consent = await confirmOrbitSocialAction(
        context,
        title: 'Match this contact?',
        description: 'Only this one selected contact address will be checked '
            'against people who opted in. Orbit does not upload your address book.',
        confirmation: 'Find friend',
        barrierDismissible: true,
      );
      if (consent != true || !mounted) return;
      final matches = await _friends.matchContacts(<Map<String, String>>[
        <String, String>{'type': selected.type, 'value': selected.value},
      ]);
      if (!mounted) return;
      OrbitPerson? eligible;
      for (final match in matches) {
        for (final person in _people) {
          if (person.id == match.id) {
            eligible = person;
            break;
          }
        }
        if (eligible != null) break;
      }
      if (eligible != null) {
        await _invite(eligible);
      } else {
        _notice('This contact is not an eligible friend for this Circle. '
            'Only existing friends can receive Circle invitations.');
      }
    } catch (_) {
      if (mounted) _notice(
          'Contact matching is unavailable. Search by username instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final eligible = _people.where((person) =>
        query.isEmpty ||
        person.name.toLowerCase().contains(query) ||
        person.username.toLowerCase().contains(query)).toList(growable: false);
    return InvitePeopleScreen(
      isCircleInvite: true,
      onBack: () => Navigator.of(context).maybePop(),
      searchController: _searchController,
      searchFocusNode: _searchFocus,
      onSearchChanged: (value) => setState(() => _query=value),
      peopleHeading: 'Friends',
      loadingPeople: _loading,
      peopleError: _error,
      onRetryPeople: _load,
      canAddPerson: !_sending && !_rateLimited,
      nearbyPeople: eligible.map((person) => NearbyPerson(
        id: person.id,
        name: person.name,
        distance: person.username.isEmpty
            ? 'Orbit friend' : '@${person.username}',
        imageAsset: '',
      )).toList(growable: false),
      onInviteByContacts: () { _pickContact(); },
      onInviteByQrCode: () => _explainRecipientBoundShare('QR code'),
      onInviteByLink: () => _explainRecipientBoundShare('link'),
      onInviteByUsername: _findUsername,
      onAddPerson: (person) {
        for (final friend in _people) {
          if (friend.id == person.id) {
            _invite(friend);
            return;
          }
        }
      },
      onOpenLogin: () => Navigator.of(context).maybePop(),
    );
  }
}
