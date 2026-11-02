import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../auth/data/orbit_identity_client.dart';
import '../../auth/presentation/screens/orbit_sessions_screen.dart';
import '../../check_in/data/orbit_check_in_repository.dart';
import '../../circles/presentation/screens/orbit_live_circles_screen.dart';
import '../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../friends/presentation/screens/orbit_friend_requests_screen.dart';
import '../../friends/presentation/screens/orbit_live_friends_screen.dart';
import '../../messaging/presentation/orbit_messaging_navigation.dart';
import '../../moments/data/orbit_moment_repository.dart';
import '../../moments/presentation/screens/orbit_live_moment_viewer.dart';
import '../../moments/presentation/screens/orbit_live_moment_notifications_screen.dart';
import '../../ping/data/orbit_ping_repository.dart';
import '../../ping/presentation/navigation/orbit_ping_navigation.dart';
import '../data/orbit_notification_repository.dart';

/// The existing Orbit white surface, header and notification ListTile style.
/// No fabricated content, persisted targets, automatic "delivered" receipt,
/// or notification-derived grant to a private feature.
class OrbitLiveNotificationsScreen extends StatefulWidget {
  const OrbitLiveNotificationsScreen({super.key,this.repository});
  final OrbitNotificationRepository? repository;
  @override
  State<OrbitLiveNotificationsScreen> createState()=>
      _OrbitLiveNotificationsScreenState();
}
class _OrbitLiveNotificationsScreenState
    extends State<OrbitLiveNotificationsScreen> with WidgetsBindingObserver {
  late final OrbitNotificationRepository _repo=
      widget.repository??OrbitNotificationRepository();
  final OrbitMomentRepository _moments=OrbitMomentRepository();
  final OrbitPingRepository _pings=OrbitPingRepository();
  final OrbitCheckInRepository _checkins=OrbitCheckInRepository();
  final List<OrbitNotificationItem> _items=[];
  String? _cursor,_owner,_error;
  bool _loading=true,_more=false,_opening=false;
  int _epoch=0;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }
  @override
  void dispose(){
    ++_epoch;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)unawaited(_load());
  }

  Future<void> _load() async {
    final serial=++_epoch;
    if(mounted)setState((){_loading=true;_error=null;});
    try{
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null)throw OrbitIdentityException('Sign in to view notifications.',401);
      final page=await _repo.page();
      if(!mounted || serial!=_epoch)return;
      if(await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner) {
        throw OrbitIdentityException('Account changed.',401);
      }
      if(mounted&&serial==_epoch)setState((){
        _owner=owner;
        _items..clear()..addAll(page.items);
        _cursor=page.nextCursor;
        _loading=false;
      });
    }catch(_){
      if(mounted&&serial==_epoch)setState((){
        _items.clear();_cursor=null;_owner=null;_loading=false;
        _error='Notifications are unavailable. Check your connection and retry.';
      });
    }
  }
  Future<void> _loadMore() async {
    final cursor=_cursor,owner=_owner;
    if(cursor==null||_more||owner==null)return;
    _more=true;
    try{
      final page=await _repo.page(cursor:cursor);
      if(!mounted||_owner!=owner ||
         await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner)return;
      final known=_items.map((e)=>e.id).toSet();
      setState((){
        _items.addAll(page.items.where((e)=>known.add(e.id)));
        _cursor=page.nextCursor;_error=null;
      });
    }catch(_){
      if(mounted)setState(()=>_error='Could not load older notifications.');
    }finally{
      _more=false;
    }
  }

  Future<void> _markAll() async {
    if(_opening)return;
    _opening=true;
    try{
      await _repo.markAllRead();
      if(mounted)await _load();
    }catch(_){
      _message('Could not mark notifications read. Please retry.');
    }finally{_opening=false;}
  }

  void _message(String message) {
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(message)));
  }

  Future<void> _open(OrbitNotificationItem item) async {
    if(_opening)return;
    _opening=true;
    try{
      final owner=_owner;
      if(owner==null ||
         await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner){
        throw StateError('Session changed.');
      }
      if(item.category=='moments'){
        // The shared M14 notice intentionally omits the private audience
        // context. Obtain it from the existing M7 current-ACL inbox.
        final rows=await _moments.notifications();
        final matches=rows.where((row)=>row['moment_id']==item.targetId &&
            row['context_id'] is String).toList();
        if(matches.isEmpty)throw StateError('Moment no longer available.');
        final legacy=matches.first;
        final moment=await _moments.notificationMoment(
          item.targetId,legacy['context_id'] as String);
        final author=await _moments.name(moment.creatorId);
        await _repo.markRead(item.id);
        try {await _moments.markNotificationRead(legacy['id'] as String);}
        catch(_){} // Unified read receipt was already acknowledged.
        if(!mounted)return;
        await Navigator.of(context).push<void>(MaterialPageRoute(
          builder:(_)=>OrbitLiveMomentViewer(
            moment:moment,repository:_moments,author:author)));
      }else if(item.category=='pings'){
        final ping=await _pings.detail(item.targetId);
        await _repo.markRead(item.id);
        if(!mounted)return;
        await OrbitPingNavigation.showIncoming(context,ping,repository:_pings);
      }else if(item.category=='check_ins'){
        final checkin=await _checkins.detail(item.targetId);
        await _repo.markRead(item.id);
        if(!mounted)return;
        await showOrbitCircleSheet<void>(
          context:context,title:'Check-In',
          builder:(sheet)=>Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text(checkin.creatorName,
                style:const TextStyle(fontWeight:FontWeight.w600)),
              const SizedBox(height:12),
              Text(checkin.label,style:AppTypography.body),
              const SizedBox(height:12),
              Text('Visible while current sharing permissions allow it.',
                style:AppTypography.bodyMuted),
              const SizedBox(height:14),
              AppPrimaryButton(label:'Close',
                onPressed:()=>Navigator.of(sheet).pop()),
            ]));
      }else {
        // Server read mutation rechecks the target's live ACL first; each
        // destination also obtains its own fresh authenticated data.
        await _repo.markRead(item.id);
        if(!mounted)return;
        switch(item.category){
          case 'messages':
            await OrbitMessagingNavigation.openList(context);
            break;
          case 'friends':
            await Navigator.of(context).push<void>(MaterialPageRoute(
              builder:(_)=>item.type=='friend.accepted'
                ?const OrbitLiveFriendsScreen()
                :const OrbitFriendRequestsScreen(initialDirection:'incoming')));
            break;
          case 'circles':
            await Navigator.of(context).push<void>(MaterialPageRoute(
              builder:(_)=>const OrbitLiveCirclesScreen()));
            break;
          case 'security':
            await Navigator.of(context).push<void>(MaterialPageRoute(
              builder:(_)=>const OrbitSessionsScreen()));
            break;
          default:throw StateError('Unsupported notification.');
        }
      }
      if(mounted)await _load();
    }catch(_){
      _message('This notification is no longer available or accessible.');
      if(mounted)await _load();
    }finally{_opening=false;}
  }

  /// Only display groups; canonical notices stay intact in _items.
  List<({OrbitNotificationItem item,int count,bool unread})> _rows() {
    final result=<({OrbitNotificationItem item,int count,bool unread})>[];
    final keys=<String,int>{};
    for(final item in _items){
      final key=item.groupKey;
      final existing=key==null?null:keys[key];
      if(existing!=null){
        final first=result[existing];
        final delta=first.item.createdAt.difference(item.createdAt).abs();
        if(delta<=const Duration(minutes:10)){
          result[existing]=(
            item:first.item,count:first.count+1,
            unread:first.unread||!item.read,
          );
          continue;
        }
      }
      if(key!=null)keys[key]=result.length;
      result.add((item:item,count:1,unread:!item.read));
    }
    return result;
  }

  IconData _icon(String category)=>switch(category){
    'moments'=>Icons.photo_camera_outlined,
    'pings'=>Icons.bolt_rounded,
    'check_ins'=>Icons.favorite_border_rounded,
    'messages'=>Icons.chat_bubble_outline_rounded,
    'friends'=>Icons.people_outline_rounded,
    'circles'=>Icons.groups_outlined,
    'security'=>Icons.shield_outlined,
    _=>Icons.notifications_none_rounded,
  };

  @override
  Widget build(BuildContext context){
    final visible=_rows();
    return Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Padding(
      padding:const EdgeInsets.fromLTRB(20,20,20,12),
      child:Column(children:[
        Row(children:[
          const Expanded(child:AppScreenHeader(
            title:'Notifications',prominent:true)),
          if(_items.any((n)=>!n.read))
            TextButton(onPressed:()=>unawaited(_markAll()),
              child:const Text('Mark all read')),
        ]),
        const SizedBox(height:18),
        Expanded(child:_loading
          ?const Center(child:CircularProgressIndicator(
              color:AppColors.primaryEnd))
          :_error!=null&&_items.isEmpty
            ?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text(_error!,textAlign:TextAlign.center,
                style:AppTypography.bodyMuted),
              TextButton(onPressed:()=>unawaited(_load()),
                child:const Text('Try again')),
              // An older server may still expose the original M7 inbox.
              // Keep it accessible until the additive M14 backend deploys.
              TextButton(
                onPressed:()=>Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder:(_)=>const OrbitLiveMomentNotificationsScreen())),
                child:const Text('Moment notifications')),
            ]))
          :_items.isEmpty && _cursor==null
            ?Center(child:Text('No notifications',
                style:AppTypography.bodyMuted))
            :RefreshIndicator(
              onRefresh:_load,
              child:ListView.separated(
                physics:const AlwaysScrollableScrollPhysics(),
                itemCount:visible.length+(_cursor==null?0:1),
                separatorBuilder:(_,__)=>const Divider(height:1),
                itemBuilder:(context,index){
                  if(index==visible.length){
                    return TextButton(
                      onPressed:_more?null:()=>unawaited(_loadMore()),
                      child:Text(_more?'Loading…':'Load more'));
                  }
                  final group=visible[index];
                  final item=group.item;
                  return ListTile(
                    contentPadding:const EdgeInsets.symmetric(vertical:5),
                    leading:Icon(_icon(item.category),
                      color:AppColors.primaryEnd),
                    title:Text(group.count==1?item.title:
                      item.title+' · '+group.count.toString()+' updates',
                      style:AppTypography.body,
                      maxLines:2,overflow:TextOverflow.ellipsis),
                    subtitle:Text(item.body,style:AppTypography.bodyMuted,
                      maxLines:3,overflow:TextOverflow.ellipsis),
                    trailing:Row(mainAxisSize:MainAxisSize.min,children:[
                      if(group.unread)const Icon(Icons.circle,
                        size:8,color:AppColors.primaryEnd),
                      const SizedBox(width:6),
                      const Icon(Icons.chevron_right_rounded),
                    ]),
                    onTap:()=>unawaited(_open(item)),
                  );
                },
              ),
            )),
      ]),
    )),
  );
  }

