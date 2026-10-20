import 'package:flutter/material.dart';

import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_circle_repository.dart';
import '../../domain/models/circle_invite.dart';
import 'circle_invite_management_screen.dart';

class OrbitLiveCircleInvitesScreen extends StatefulWidget {
  const OrbitLiveCircleInvitesScreen({required this.circle,super.key,this.repository});
  final OrbitCircle circle;
  final OrbitCircleRepository? repository;
  @override
  State<OrbitLiveCircleInvitesScreen> createState()=>_OrbitLiveCircleInvitesScreenState();
}

class _OrbitLiveCircleInvitesScreenState extends State<OrbitLiveCircleInvitesScreen> {
  late final OrbitCircleRepository _repo=widget.repository ?? OrbitCircleRepository();
  List<CircleInvite> _invites=const [];
  bool _busy=true;
  String? _error;

  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    if(mounted) setState(() {_busy=true;_error=null;});
    try {
      final result=<CircleInvite>[];
      for (var p=1;p<=20;p++) {
        final response=await _repo.outgoing(widget.circle.id,page:p);
        for(final invite in response.items){
          final person=invite.person;
          if(person==null) continue;
          final status=switch(invite.status){
            'accepted'=>CircleInviteStatus.accepted,
            'declined'=>CircleInviteStatus.declined,
            _=>CircleInviteStatus.pending,
          };
          result.add(CircleInvite(
            id:invite.id,userId:person.id,userName:person.name,
            avatarUrl:'',status:status,createdAt:DateTime.now(),
          ));
        }
        if(!response.hasMore) break;
      }
      if(mounted) setState(() {_invites=result;_busy=false;});
    } catch(_) {
      if(mounted) setState(() {
        _error='Unable to load Circle invitations. Reconnect and retry.';
        _busy=false;
      });
    }
  }

  CircleInviteTabData _tab(CircleInviteTab tab) {
    if(_busy) return const CircleInviteTabData(state:CircleInviteViewState.loading);
    if(_error!=null) return CircleInviteTabData(
      state:CircleInviteViewState.error,errorMessage:_error);
    final selected=switch(tab){
      CircleInviteTab.sent=>_invites,
      CircleInviteTab.pending=>_invites.where((x)=>x.status==CircleInviteStatus.pending)
        .toList(growable:false),
      CircleInviteTab.accepted=>_invites.where((x)=>x.status==CircleInviteStatus.accepted)
        .toList(growable:false),
    };
    return CircleInviteTabData(
      state:selected.isEmpty ? CircleInviteViewState.empty : CircleInviteViewState.loaded,
      invites:selected,
    );
  }

  Future<void> _pressed(CircleInvite invite) async {
    if(invite.status!=CircleInviteStatus.pending) return;
    final agree=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      backgroundColor:Colors.white,
      title:const Text('Revoke invitation?'),
      content:Text('Cancel the pending invitation for ${invite.userName}?'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Keep')),
        TextButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Revoke')),
      ],
    ));
    if(agree!=true) return;
    try {
      await _repo.revoke(widget.circle.id,invite.id);
      if(mounted) await _load();
    } catch(e){
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(e is OrbitIdentityException ? e.message :
          'Could not revoke invitation.')));
    }
  }

  @override
  Widget build(BuildContext context)=>CircleInviteManagementScreen(
    sent:_tab(CircleInviteTab.sent),
    pending:_tab(CircleInviteTab.pending),
    accepted:_tab(CircleInviteTab.accepted),
    onBack:()=>Navigator.of(context).maybePop(),
    onRetry:(_)=>_load(),
    onInvitePressed:_pressed,
  );
}
