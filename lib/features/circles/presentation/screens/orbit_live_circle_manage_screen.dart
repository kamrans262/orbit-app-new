import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_circle_repository.dart';
import 'orbit_live_circle_invites_screen.dart';
import 'orbit_live_invite_member_screen.dart';

/// Server permissions determine which management controls are displayed.
/// Member and Restricted can read their authorized roster and leave only.
class OrbitLiveCircleManageScreen extends StatefulWidget {
  const OrbitLiveCircleManageScreen({
    required this.circle,super.key,this.repository,
  });
  final OrbitCircle circle;
  final OrbitCircleRepository? repository;
  @override
  State<OrbitLiveCircleManageScreen> createState()=>_OrbitLiveCircleManageScreenState();
}

class _OrbitLiveCircleManageScreenState extends State<OrbitLiveCircleManageScreen> {
  late final OrbitCircleRepository _repo=widget.repository ?? OrbitCircleRepository();
  late OrbitCircle _circle=widget.circle;
  List<OrbitCircleMember> _members=const [];
  bool _busy=true;
  String? _error;
  int _version=0;

  @override
  void initState(){super.initState();_load();}
  @override
  void dispose(){_version++;super.dispose();}

  Future<void> _load() async {
    final epoch=++_version;
    setState(() {_busy=true;_error=null;});
    try {
      final circle=await _repo.detail(_circle.id);
      final members=<OrbitCircleMember>[];
      for(var p=1;p<=20;p++){
        final response=await _repo.members(_circle.id,page:p);
        members.addAll(response.items);
        if(!response.hasMore) break;
      }
      if(!mounted || epoch!=_version)return;
      setState(() {_circle=circle;_members=members;_busy=false;});
    } catch(_){
      if(!mounted || epoch!=_version)return;
      setState(() {_error='Circle permissions could not be verified.';
        _members=const [];_busy=false;});
    }
  }

  void _errorNotice(Object error){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
      error is OrbitIdentityException ? error.message : 'Circle action failed. Please retry.',
    )));
  }

  Future<bool> _confirm(String title,String text,String action) async =>
      await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
        backgroundColor:Colors.white,title:Text(title),
        content:Text(text),actions:[
          TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),
          TextButton(onPressed:()=>Navigator.pop(d,true),child:Text(action)),
        ],
      )) ?? false;

  Future<void> _setPrimary() async {
    try {
      await _repo.choosePrimary(_circle.id);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Primary Circle updated.')));
    } catch(e){_errorNotice(e);}
  }

  Future<void> _invite() async {
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitLiveInviteMemberScreen(
        circleId:_circle.id,repository:_repo)));
    if(mounted)await _load();
  }

  Future<void> _invites() async{
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitLiveCircleInvitesScreen(circle:_circle,repository:_repo)));
    if(mounted)await _load();
  }

  Future<void> _leave() async{
    if(!await _confirm('Leave Circle?','You will lose access to this Circle.','Leave'))return;
    try {
      await _repo.leave(_circle.id);
      if(mounted) Navigator.of(context).pop();
    }catch(e){_errorNotice(e);}
  }

  Future<void> _remove(OrbitCircleMember member) async {
    if(!await _confirm('Remove member?','Remove ${member.name} from this Circle?','Remove'))return;
    try {
      await _repo.remove(_circle.id,member.id);
      if(mounted)await _load();
    }catch(e){_errorNotice(e);}
  }

  Future<void> _changeRole(OrbitCircleMember member,String role) async {
    if(!await _confirm('Change role?', 'Set ${member.name} to ${role.toUpperCase()}?','Confirm'))return;
    try {
      await _repo.changeRole(_circle.id,member.id,role);
      if(mounted)await _load();
    }catch(e){_errorNotice(e);}
  }

  Future<void> _transfer(OrbitCircleMember member) async {
    if(!await _confirm('Transfer ownership?',
      '${member.name} will become the sole Circle Owner. '
      'You will become an Admin. This cannot be undone without their action.',
      'Transfer'))return;
    try {
      await _repo.transferOwner(_circle.id,member.id);
      if(mounted)Navigator.of(context).pop();
    }catch(e){_errorNotice(e);}
  }

  Future<void> _archive() async{
    if(!await _confirm('Archive Circle?',
      'This hides the Circle and cancels pending invitations. No data is permanently deleted.',
      'Archive'))return;
    try {
      await _repo.archive(_circle.id);
      if(mounted)Navigator.of(context).pop();
    }catch(e){_errorNotice(e);}
  }

  Widget _item(IconData icon,String title,VoidCallback? callback,
      {String? subtitle,Color? color})=>Card(
      elevation:0,color:Colors.white,
      child:ListTile(
        leading:Icon(icon,color:color??const Color(0xFF7C3AED)),
        title:Text(title,style:TextStyle(
          fontFamily:AppTypography.fontFamily,fontWeight:FontWeight.w500,
          color:color??const Color(0xFF0F1724))),
        subtitle:subtitle==null ? null :Text(subtitle,style:const TextStyle(
          fontFamily:AppTypography.fontFamily,fontSize:12)),
        onTap:callback,
        trailing:callback==null ? null :const Icon(Icons.chevron_right_rounded),
      ),
    );

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    appBar:AppBar(backgroundColor:AppColors.background,
      title:const Text('Manage Circle',style:TextStyle(
        fontFamily:AppTypography.fontFamily,fontWeight:FontWeight.w600))),
    body:_busy ? const Center(child:CircularProgressIndicator())
      : _error!=null ? Center(child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            Text(_error!),TextButton(onPressed:_load,child:const Text('Try again')),
          ]))
      :ListView(padding:const EdgeInsets.all(20),children:[
        Text(_circle.name,style:const TextStyle(
          fontFamily:AppTypography.fontFamily,fontSize:20,fontWeight:FontWeight.w600)),
        const SizedBox(height:8),
        Text('Your role: ${_circle.role.toUpperCase()}',
          style:const TextStyle(fontFamily:AppTypography.fontFamily,color:Color(0xFF64748B))),
        const SizedBox(height:16),
        _item(Icons.star_outline,'Set as primary Circle',_setPrimary),
        if(_circle.can('invite')) ...[
          _item(Icons.person_add_alt_1_outlined,'Invite friends',_invite),
          _item(Icons.mail_outline,'Manage invitations',_invites),
        ],
        if(_circle.can('archive'))
          _item(Icons.archive_outlined,'Archive Circle',_archive,
            subtitle:'Reversible. Pending invitations will be cancelled.'),
        if(_circle.can('leave'))
          _item(Icons.logout_rounded,'Leave Circle',_leave,color:const Color(0xFFB91C1C)),
        const SizedBox(height:16),
        const Text('Members',style:TextStyle(
          fontFamily:AppTypography.fontFamily,fontSize:18,fontWeight:FontWeight.w600)),
        const SizedBox(height:8),
        for(final member in _members)
          Card(elevation:0,color:Colors.white,child:ListTile(
            leading:const CircleAvatar(backgroundColor:Color(0xFFE9E4F6),
              child:Icon(Icons.person_outline,color:Color(0xFF7C3AED))),
            title:Text(member.name,style:const TextStyle(
              fontFamily:AppTypography.fontFamily,fontWeight:FontWeight.w500)),
            subtitle:Text('${member.username.isEmpty ? '' : '@${member.username} • '}${member.role}'),
            trailing:_circle.can('remove_members') && member.role!='owner'
              ? PopupMenuButton<String>(
                  tooltip:'Manage member',
                  onSelected:(choice){
                    if(choice=='remove') {_remove(member);return;}
                    if(choice=='transfer') {_transfer(member);return;}
                    _changeRole(member,choice);
                  },
                  itemBuilder:(_)=>[
                    if(_circle.can('change_roles'))
                      for(final role in const ['admin','member','restricted'])
                        PopupMenuItem(value:role,child:Text('Set ${role.toUpperCase()}')),
                    if(_circle.can('transfer_owner') && member.role!='restricted')
                      const PopupMenuItem(value:'transfer',child:Text('Transfer ownership')),
                    const PopupMenuItem(value:'remove',child:Text('Remove member')),
                  ],
                ) : null,
          )),
        const SizedBox(height:20),
        const Text('Joining a Circle never enables location, presence, Moments, '
          'Ping, messaging or SOS sharing.',
          style:TextStyle(fontFamily:AppTypography.fontFamily,
            fontSize:12,color:Color(0xFF64748B))),
      ]),
  );
}
