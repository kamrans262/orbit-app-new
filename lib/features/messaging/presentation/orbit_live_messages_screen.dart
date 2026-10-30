import 'dart:async';
import 'package:flutter/material.dart';

import '../../../circles/data/orbit_circle_repository.dart';
import '../../../circles/domain/models/friend_details_models.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../data/orbit_messaging_api.dart';
import '../data/orbit_messaging_models.dart';
import 'orbit_messaging_navigation.dart';

/// The original Messages widget with server-authorized conversations.
/// Friend rows shown without an existing thread are real current friendships,
/// not seeded demo people. No private message snippets are cached or exposed.
class OrbitLiveMessagesScreen extends StatefulWidget {
  const OrbitLiveMessagesScreen({super.key,this.messaging,this.social,this.circles});
  final OrbitMessagingApi? messaging;
  final OrbitSocialRepository? social;
  final OrbitCircleRepository? circles;
  @override
  State<OrbitLiveMessagesScreen> createState()=>_OrbitLiveMessagesScreenState();
}
class _OrbitLiveMessagesScreenState extends State<OrbitLiveMessagesScreen>
    with WidgetsBindingObserver {
  late final OrbitMessagingApi _api=widget.messaging??OrbitMessagingApi();
  late final OrbitSocialRepository _social=widget.social??OrbitSocialRepository();
  late final OrbitCircleRepository _circles=widget.circles??OrbitCircleRepository();
  final Map<String,OrbitConversation> _threads={};
  final Map<String,String> _names={};
  final List<FriendMemberData> _rows=[];
  String? _status;
  bool _loading=true;
  int _epoch=0;
  Timer? _reload;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // HTTPS fallback only. This is polling, not realtime or push.
    _reload=Timer.periodic(const Duration(seconds:25),(_){
      if(mounted &&
          WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent==true) {
        unawaited(_load(silent:true));
      }
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)unawaited(_load(silent:true));
  }
  @override
  void dispose(){
    _epoch++;
    _reload?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool silent=false}) async {
    final epoch=++_epoch;
    if(!silent)setState((){_loading=true;_status=null;});
    try{
      final capabilities=await _api.capabilities();
      if(!capabilities.available){
        throw StateError('Messaging backend is not available on this server.');
      }
      final threads=<OrbitConversation>[];
      for(var page=1;page<=3;page++){
        final data=await _api.conversations(page:page);
        threads.addAll(data.items);
        if(!data.hasMore)break;
      }
      final friends=<OrbitPerson>[];
      for(var page=1;page<=10;page++){
        final data=await _social.friends(page:page);
        friends.addAll(data.items);
        if(!data.hasMore)break;
      }
      final circleNames=<String,String>{};
      for(var page=1;page<=10;page++){
        final data=await _circles.list(page:page);
        for(final circle in data.items)circleNames[circle.id]=circle.name;
        if(!data.hasMore)break;
      }
      final friendNames=<String,String>{
        for(final p in friends)p.id:p.name,
      };
      final seenUsers=<String>{};
      final result=<FriendMemberData>[];
      final byId=<String,OrbitConversation>{};
      final newNames=<String,String>{};
      for(final c in threads) {
        if(c.archived)continue;
        final circle=c.kind=='circle';
        final key='conversation:'+c.id;
        final name=circle?(circleNames[c.circleId]??'Private Circle'):
          (friendNames[c.peerId]??'Orbit friend');
        newNames[key]=name;
        if(!circle && c.peerId!=null)seenUsers.add(c.peerId!);
        byId[key]=c;
        result.add(FriendMemberData(
          id:key,name:name,imagePath:null,
          status:(circle?'Circle Chat':'Direct Chat')+
            (c.unreadEnvelopes>0
              ?' · '+c.unreadEnvelopes.toString()+' pending encrypted messages'
              :' · Private'),
        ));
      }
      for(final friend in friends){
        if(seenUsers.contains(friend.id))continue;
        final key='friend:'+friend.id;
        newNames[key]=friend.name;
        result.add(FriendMemberData(
          id:key,name:friend.name,imagePath:null,
          status:'Friend · Start a private conversation',
        ));
      }
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _rows..clear()..addAll(result);
        _threads..clear()..addAll(byId);
        _names..clear()..addAll(newNames);
        _loading=false;_status=null;
      });
    }catch(error){
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _rows.clear();_threads.clear();_names.clear();
        _loading=false;
        _status=error is StateError
          ?error.message
          :'Messages are unavailable. Reconnect to verify your session and permissions.';
      });
    }
  }

  void _open(FriendMemberData data){
    final value=_threads[data.id];
    if(value==null){
      if(!data.id.startsWith('friend:'))return;
      OrbitMessagingNavigation.openDirect(context,
        peerId:data.id.substring(7),peerName:data.name);
    }else if(value.kind=='circle' && value.circleId!=null){
      OrbitMessagingNavigation.openCircle(context,
        circleId:value.circleId!,circleName:data.name);
    }else if(value.kind=='direct' && value.peerId!=null){
      OrbitMessagingNavigation.openDirect(context,
        peerId:value.peerId!,peerName:data.name);
    }
  }
  @override
  Widget build(BuildContext context)=>MessagesScreen(
    friends:_rows,isLoading:_loading,statusMessage:_status,
    onOpenFriend:_open,
    onBack:()=>Navigator.of(context).maybePop(),
  );
}
