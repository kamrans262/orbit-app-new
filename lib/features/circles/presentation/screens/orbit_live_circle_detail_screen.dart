import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../data/orbit_circle_repository.dart';
import '../widgets/orbit_circle_sheet.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../data/orbit_circle_change_source.dart';
import '../../data/orbit_m5_firebase_change_source.dart';
import '../../domain/models/friend_details_models.dart';
import 'friend_details_screen.dart';
import 'orbit_live_circle_settings_screen.dart';
import 'orbit_live_invite_member_screen.dart';
import '../../../profile/presentation/screens/orbit_live_profile_moments.dart';
import '../../../moments/data/orbit_m7_rollout.dart';

class OrbitLiveCircleDetailScreen extends StatefulWidget {
  const OrbitLiveCircleDetailScreen({required this.circleId,super.key,this.repository,this.changeSource});
  final String circleId;
  final OrbitCircleRepository? repository;
  final OrbitCircleChangeSource? changeSource;
  @override
  State<OrbitLiveCircleDetailScreen> createState() => _OrbitLiveCircleDetailScreenState();
}

class _OrbitLiveCircleDetailScreenState extends State<OrbitLiveCircleDetailScreen>
    with WidgetsBindingObserver {
  late final OrbitCircleRepository _repo=widget.repository ?? OrbitCircleRepository();
  OrbitCircle? _circle;
  List<OrbitCircleMember> _members = const [];
  bool _loading = true;
  String? _error;
  int _epoch = 0;
  Timer? _authorizationRefresh;
  StreamSubscription<OrbitCircleInvalidation>? _invalidationSubscription;
  bool _revalidating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.changeSource == null) {
      OrbitM5FirebaseChangeSource.instance.setBootstrap(_repo.realtimeBootstrap);
    }
    _invalidationSubscription=(widget.changeSource ??
        OrbitM5FirebaseChangeSource.instance).invalidations.listen((event) {
      if(event.circleId==widget.circleId && mounted &&
          !_loading && !_revalidating) _refresh(silent:true);
    });
    _authorizationRefresh=Timer.periodic(const Duration(seconds:25),(_){
      if(!mounted || _loading || _revalidating ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true) return;
      _refresh(silent:true);
    });
    if (widget.changeSource == null) {
      unawaited(OrbitM5FirebaseChangeSource.instance.watchCircles(
        [widget.circleId],
      ));
    }
    _refresh();
  }

  @override
  void dispose() {
    _epoch++;
    _authorizationRefresh?.cancel();
    _invalidationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    if(silent && _revalidating)return;
    if(silent) _revalidating=true;
    final epoch=++_epoch;
    if(!silent && mounted) setState(() {_loading=true;_error=null;});
    try {
      final circle=await _repo.detail(widget.circleId);
      final members=<OrbitCircleMember>[];
      for (var p=1;p<=20;p++) {
        final result=await _repo.members(widget.circleId,page:p);
        members.addAll(result.items);
        if(!result.hasMore) break;
      }
      if(!mounted || epoch!=_epoch) return;
      setState(() {_circle=circle; _members=members; _loading=false;});
    } catch (_) {
      if(!mounted || epoch!=_epoch) return;
      setState(() {
        _circle=null;_members=const [];
        _error='Circle access could not be verified. Reconnect or return to My Circles.';
        _loading=false;
      });
    } finally {
      if(silent) _revalidating=false;
    }
  }

  String? _temporaryNotice() {
    final circle=_circle;
    if(circle==null || circle.expiresAt==null)return null;
    if(circle.lifecycleState=='read_only') {
      return 'This temporary Circle has expired. '
        'It stays read-only for 72 hours, then moves to archive without deleting data.';
    }
    final remaining=circle.expiresAt!.difference(DateTime.now());
    if(remaining.isNegative)return 'Temporary Circle expiry is being verified.';
    if(remaining<=const Duration(hours:24)) {
      return 'This Circle expires within 24 hours. '
        'It becomes read-only at its expiry time.';
    }
    return null;
  }

  Future<void> _memberPreview(OrbitCircleMember member) async {
    if (_circle == null) return;
    await showOrbitCircleSheet<void>(
      context: context,
      title: 'Circle member',
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFF2EAFE),
                child: Icon(Icons.person_outline_rounded,
                    size: 30, color: AppColors.primaryEnd),
              ),
              const SizedBox(height: 12),
              Text(member.name, textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 18, fontWeight: FontWeight.w600,
                  color: Color(0xFF0F1724),
                )),
              if (member.username.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('@${member.username}', textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13, color: Color(0xFF64748B),
                  )),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          AppActionRow(
            leadingIcon: Icons.shield_outlined,
            iconBackgroundColor: const Color(0xFFF2EAFE),
            leadingIconColor: AppColors.primaryEnd,
            title: 'Role: ${member.role.toUpperCase()}',
          ),
          const SizedBox(height: 10),
          const AppActionRow(
            leadingIcon: Icons.lock_outline_rounded,
            iconBackgroundColor: Color(0xFFF2EAFE),
            leadingIconColor: AppColors.primaryEnd,
            title: 'Live presence and location are private',
          ),
        ],
      ),
    );
  }

  Future<void> _openInvite() async {
    final circle=_circle;
    if(circle==null || !circle.can('invite')) return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder: (_) => OrbitLiveInviteMemberScreen(
        circleId:circle.id,repository:_repo)));
    if(mounted) await _refresh();
  }

  Future<void> _openSettings() async {
    final circle=_circle;
    if(circle==null) return;
    final outcome=await Navigator.of(context).push<String>(
      AppFadeSlidePageRoute<String>(
        builder: (_) => OrbitLiveCircleSettingsScreen(
          circle:circle,repository:_repo)));
    if(!mounted)return;
    if(outcome=='unavailable') {
      Navigator.of(context).maybePop();
      return;
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    FriendDetailsScreen(
      circleName: _circle?.name ?? 'Circle',
      members: _members.map((p) => FriendMemberData(
        id:p.id,name:p.name,
        status:'${p.username.isEmpty ? p.role : '@${p.username} • ${p.role}'}',
        imagePath:null,
        onTap:()=>_memberPreview(p),
      )).toList(growable:false),
      groups:const <CircleGroupData>[],
      onBack: () => Navigator.of(context).maybePop(),
      onAddMember: _openInvite,
      liveInviteMode: true,
      headerTitle:'Circle Details',
      lifecycleNotice:_temporaryNotice(),
      showGroupSegment:false,
      showFavoriteActions:false,
      momentsTabBuilder:OrbitM7Rollout.enabled && _circle!=null
        ? (_)=>OrbitLiveProfileMoments(
          key:ValueKey<String>('circle_moments_${_circle!.id}'),
          circleId:_circle!.id,
        ) : null,
      showAddMemberButton: _circle?.can('invite') == true,
      viewState:_loading ? FriendDetailsViewState.loading
        : _error!=null ? FriendDetailsViewState.error
        : FriendDetailsViewState.loaded,
      errorMessage:_error ?? 'Unable to load Circle members.',
      onRetry:_refresh,
    ),
    if(!_loading && _circle!=null)
      Positioned(right:20,bottom:25,
        child: FloatingActionButton.extended(
          heroTag:'m5-circle-settings',
          backgroundColor:AppColors.background,
          foregroundColor:const Color(0xFF7C3AED),
          onPressed:_openSettings,
          label:const Text('Circle settings'),
          icon:const Icon(Icons.settings_outlined),
        )),
  ]);
}
