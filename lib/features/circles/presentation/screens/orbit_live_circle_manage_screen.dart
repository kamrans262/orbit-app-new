import 'package:flutter/material.dart';

import '../widgets/orbit_circle_confirmation.dart';
import '../widgets/orbit_circle_sheet.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
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
  String? _primaryCircleId;
  bool _primaryFallback = false;
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
      final primary=await _repo.primary();
      if(!mounted || epoch!=_version)return;
      setState(() {
        _circle=circle;_members=members;_busy=false;
        _primaryCircleId=primary['circle_id'] as String?;
        _primaryFallback=primary['fallback']==true;
      });
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

  Future<bool> _confirm(String title,String text,String action) =>
    showOrbitCircleConfirmation(
      context:context,
      title:title,
      description:text,
      confirmLabel:action,
      destructive: const <String>{'Leave','Remove','Transfer','Archive'}.contains(action),
    );

  Future<void> _editIcon() async {
    if(!_circle.can('edit'))return;
    const icons=<String,IconData>{
      'home':Icons.home_rounded,'person':Icons.account_circle_outlined,
      'star':Icons.star_border_rounded,'music':Icons.music_note_rounded,
      'location':Icons.location_on_outlined,'sunny':Icons.wb_sunny_outlined,
    };
    final choice = await showOrbitCircleSheet<String>(
      context: context,
      title: 'Choose Circle icon',
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in icons.entries) ...[
            OrbitCircleSheetAction(
              title: entry.key[0].toUpperCase() + entry.key.substring(1),
              icon: entry.value,
              onTap: () => Navigator.of(sheet).pop(entry.key),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
    if(choice==null || choice==_circle.iconKey)return;
    try {
      final updated=await _repo.update(_circle.id,icon:choice);
      if(mounted)setState(()=>_circle=updated);
    }catch(e){_errorNotice(e);}
  }

  Future<void> _setPrimary() async {
    try {
      final primary=await _repo.primary();
      if(primary['circle_id']==_circle.id && primary['fallback']!=true) return;
      await _repo.choosePrimary(_circle.id);
      if(mounted) {
        setState(() {_primaryCircleId=_circle.id;_primaryFallback=false;});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Primary Circle updated.')));
      }
    } catch(e){_errorNotice(e);}
  }

  Future<void> _clearPrimary() async {
    try {
      final resolved=await _repo.choosePrimary(null);
      if(!mounted)return;
      setState((){
        _primaryCircleId=resolved['circle_id'] as String?;
        _primaryFallback=resolved['fallback']==true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Manual primary selection cleared. Default Circle restored.')));
    }catch(e){_errorNotice(e);}
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
      if(mounted) Navigator.of(context).pop('left');
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
      if(mounted)Navigator.of(context).pop('archived');
    }catch(e){_errorNotice(e);}
  }

  Future<void> _manageMember(OrbitCircleMember member) async {
    if (member.role == 'owner') return;
    final canRemove = _circle.can('remove_members');
    final canChangeRole = _circle.can('change_roles');
    final canTransfer = _circle.can('transfer_owner') &&
        member.role != 'restricted';
    if (!canRemove && !canChangeRole && !canTransfer) return;

    final action = await showOrbitCircleSheet<String>(
      context: context,
      title: member.name,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppActionRow(
            leadingIcon: Icons.person_outline_rounded,
            iconBackgroundColor: const Color(0xFFF2EAFE),
            leadingIconColor: AppColors.primaryEnd,
            title: member.username.isEmpty
                ? member.role.toUpperCase()
                : '@${member.username} • ${member.role.toUpperCase()}',
          ),
          const SizedBox(height: 12),
          if (canChangeRole)
            for (final role in const ['admin', 'member', 'restricted']) ...[
              OrbitCircleSheetAction(
                title: 'Set ${role.toUpperCase()}',
                icon: Icons.manage_accounts_outlined,
                onTap: () => Navigator.of(sheet).pop('role:$role'),
              ),
              const SizedBox(height: 10),
            ],
          if (canTransfer) ...[
            OrbitCircleSheetAction(
              title: 'Transfer ownership',
              icon: Icons.swap_horiz_rounded,
              onTap: () => Navigator.of(sheet).pop('transfer'),
            ),
            const SizedBox(height: 10),
          ],
          if (canRemove)
            OrbitCircleSheetAction(
              title: 'Remove member',
              icon: Icons.person_remove_outlined,
              destructive: true,
              onTap: () => Navigator.of(sheet).pop('remove'),
            ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') return _remove(member);
    if (action == 'transfer') return _transfer(member);
    if (action.startsWith('role:')) return _changeRole(member, action.substring(5));
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
    body:SafeArea(child:Column(children:[
      const Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,0),
        child:AppScreenHeader(title:'Manage Circle'),
      ),
      const SizedBox(height:20),
      Expanded(child:_busy ? const Center(child:CircularProgressIndicator())
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
        _item(Icons.star_outline,
          _primaryCircleId==_circle.id
            ? (_primaryFallback ? 'Default Circle' : 'Primary Circle')
            : 'Set as primary Circle',
          _primaryCircleId==_circle.id && !_primaryFallback ? null : _setPrimary),
        if(_primaryCircleId==_circle.id && !_primaryFallback)
          _item(Icons.star_border_outlined,'Clear primary selection',_clearPrimary,
            subtitle:'Orbit will use a safe default among your Circles.'),
        if(_circle.can('edit'))
          _item(Icons.palette_outlined,'Change Circle icon',_editIcon,
            subtitle:'Current: ${_circle.iconKey ?? 'Default'}'),
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
            trailing:member.role!='owner' &&
              (_circle.can('remove_members') ||
               _circle.can('change_roles') ||
               (_circle.can('transfer_owner') && member.role != 'restricted'))
              ? AppCircularIconButton(
                  key: Key('circle_member_more_${member.id}'),
                  semanticLabel: 'Manage ${member.name}',
                  icon: Icons.more_horiz_rounded,
                  iconSize: 24,
                  iconColor: Colors.black,
                  onPressed: () => _manageMember(member),
                ) : null,
          )),
        const SizedBox(height:20),
        const Text('Joining a Circle never enables location, presence, Moments, '
          'Ping, messaging or SOS sharing.',
          style:TextStyle(fontFamily:AppTypography.fontFamily,
            fontSize:12,color:Color(0xFF64748B))),
      ]),
      ),
    ])),
  );
}
