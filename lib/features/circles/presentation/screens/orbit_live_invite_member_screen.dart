import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
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
  bool _loading=true,_sending=false;
  String? _error;
  DateTime? _rateLimitedUntil;
  Timer? _rateLimitTimer;

  bool get _rateLimited => _rateLimitedUntil != null &&
      DateTime.now().isBefore(_rateLimitedUntil!);

  @override
  void dispose() { _rateLimitTimer?.cancel(); super.dispose(); }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Invitation sent. Awaiting acceptance.')));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invitation limit reached. Please try again in about a minute.'),
        ));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is OrbitIdentityException ? e.message
              : 'Unable to invite this friend.'),
        ));
      }
    } finally {
      if(mounted) setState(()=>_sending=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Column(children:[
      const Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,0),
        child:AppScreenHeader(title:'Invite friends'),
      ),
      const SizedBox(height:20),
      Expanded(child:_loading ? const Center(child:CircularProgressIndicator())
      : _error!=null ? Center(child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            Text(_error!,textAlign:TextAlign.center),
            TextButton(onPressed:_load,child:const Text('Try again')),
          ]))
      : _people.isEmpty ? const Center(child:Text('No eligible friends to invite. Existing members and pending invitations are excluded.'))
      : ListView.builder(
        keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
        padding:const EdgeInsets.all(20),
        itemCount:_people.length,
        itemBuilder:(context,index){
          final p=_people[index];
          return Card(color:Colors.white,elevation:0,
            child:ListTile(
              title:Text(p.name,style:const TextStyle(
                fontFamily:AppTypography.fontFamily,fontWeight:FontWeight.w500)),
              subtitle:Text('@${p.username}'),
              trailing:TextButton(
                onPressed:(_sending || _rateLimited) ? null : ()=>_invite(p),
                child: Opacity(
                  opacity: (_sending || _rateLimited) ? 0.45 : 1,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.primaryStart, AppColors.primaryEnd],
                    ).createShader(bounds),
                    child: const Text(
                      'Invite',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ));
        },
      ),
      ),
    ])),
  );
}
