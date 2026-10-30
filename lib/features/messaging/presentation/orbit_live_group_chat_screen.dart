import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../circles/data/orbit_circle_repository.dart';
import '../../group_chat/domain/models/group_chat_models.dart';
import '../../group_chat/presentation/screens/group_chat_screen.dart';
import '../data/orbit_messaging_api.dart';
import '../data/orbit_messaging_coordinator.dart';
import '../data/orbit_messaging_models.dart';
import '../data/orbit_messaging_media_bridge.dart';
import '../data/orbit_messaging_reactions.dart';
import '../data/orbit_messaging_replies.dart';
import '../../../core/navigation/app_fade_slide_page_route.dart';
import 'orbit_private_chat_video_viewer.dart';
import 'orbit_messaging_conversation_actions.dart';

/// Wraps the APPROVED GroupChatScreen with live M5 Circle roles and M13
/// ciphertext mailbox. No generated participants or fake media messages.
class OrbitLiveGroupChatScreen extends StatefulWidget {
  const OrbitLiveGroupChatScreen({
    required this.circleId,required this.circleName,
    super.key,this.messaging,this.coordinator,this.circles});
  final String circleId,circleName;
  final OrbitMessagingApi? messaging;
  final OrbitMessagingCoordinator? coordinator;
  final OrbitCircleRepository? circles;
  @override
  State<OrbitLiveGroupChatScreen> createState()=>_OrbitLiveGroupChatScreenState();
}
class _OrbitLiveGroupChatScreenState extends State<OrbitLiveGroupChatScreen>
    with WidgetsBindingObserver{
  late final OrbitMessagingApi _api=widget.messaging??OrbitMessagingApi();
  late final OrbitMessagingCoordinator _messenger=widget.coordinator??
    OrbitMessagingCoordinator(api:_api);
  late final OrbitCircleRepository _circles=widget.circles??OrbitCircleRepository();
  final OrbitMessagingMediaBridge _media=OrbitMessagingMediaBridge();
  List<GroupChatMessage> _messages=const [];
  List<GroupParticipant> _participants=const [];
  OrbitConversation? _thread;
  String? _owner;
  bool _loading=true,_cryptoReady=false;
  String? _error;
  Timer? _timer;
  int _epoch=0;
  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer=Timer.periodic(const Duration(seconds:25),(_){
      if(!mounted || ModalRoute.of(context)?.isCurrent!=true ||
          WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed)return;
      unawaited(_load());
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed)unawaited(_load());
  }
  @override
  void dispose(){
    _epoch++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  String _time(DateTime date){
    final local=date.toLocal(),h=local.hour;
    return (h%12==0?12:h%12).toString()+':'+local.minute.toString().padLeft(2,'0')
      +(h>=12?' PM':' AM');
  }
  Future<void> _load() async {
    final epoch=++_epoch;
    if(_thread==null && mounted)setState(()=>_loading=true);
    try{
      final owner=await _api.owner;
      final conversation=await _api.circle(widget.circleId);
      final people=<GroupParticipant>[];
      for(var page=1;page<=10;page++){
        final result=await _circles.members(widget.circleId,page:page);
        people.addAll(result.items.map((m)=>GroupParticipant(
          id:m.id,name:m.name,avatarPath:null)));
        if(!result.hasMore)break;
      }
      final names={for(final item in people)item.id:item.name};
      final ready=await _messenger.secureReady();
      List<GroupChatMessage> next=const [];
      if(ready){
        final history=await _messenger.refresh(conversation);
        final reactionState=OrbitReactionReducer.fold(history,localUser:owner);
        final loaded=<GroupChatMessage>[];
        for(final entry in history){
          if(entry.kind=='reaction')continue;
          final reply=entry.kind=='reply'
            ?OrbitEncryptedReply.fromText(entry.text):null;
          final manifest=OrbitEncryptedChatMedia.tryParse(entry.text);
          var type=entry.senderId==owner
            ?GroupChatMessageType.sentText:GroupChatMessageType.receivedText;
          String? text=entry.text;
          if(reply!=null){
            final original=history.where((e)=>e.id==reply.targetId).toList();
            final quote=original.isEmpty?'Original message':original.first.text;
            text='↪ '+(quote.length>60?quote.substring(0,60)+'…':quote)+
              '\n'+reply.text;
          }
          Uint8List? bytes;
          Duration? audioLength;
          if(manifest!=null){
            try {
              bytes=await _media.open(manifest);
              if(manifest.kind=='image'){
                type=entry.senderId==owner
                  ?GroupChatMessageType.sentImage:GroupChatMessageType.receivedImage;
              }else if(manifest.kind=='voice'){
                type=entry.senderId==owner
                  ?GroupChatMessageType.sentVoice:GroupChatMessageType.receivedVoice;
                audioLength=Duration(milliseconds:manifest.durationMs??1000);
              }else{
                type=GroupChatMessageType.futureVideo;
              }
              text=null;
            }catch(_){
              text='Encrypted media is no longer available.';
              type=entry.senderId==owner
                ?GroupChatMessageType.sentText:GroupChatMessageType.receivedText;
            }
          }
          loaded.add(GroupChatMessage(
            id:entry.id,type:type,senderId:entry.senderId,
            senderName:entry.senderId==owner
              ?'You':names[entry.senderId]??'Circle member',
            isMine:entry.senderId==owner,text:text,
            imageBytes:manifest?.kind=='image'?bytes:null,
            videoBytes:manifest?.kind=='video'?bytes:null,
            audioBytes:manifest?.kind=='voice'?bytes:null,
            audioDuration:audioLength,
            reactions:reactionState[entry.id]?.counts??const <String,int>{},
            selectedReaction:reactionState[entry.id]?.selected,
            timestamp:_time(entry.createdAt),createdAt:entry.createdAt));
        }
        next=loaded;
      }
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _thread=conversation;_owner=owner;
        _participants=people;_messages=next;_cryptoReady=ready;
        _loading=false;
        _error=ready?null:'This Circle requires verified end-to-end encryption '
          'and a reviewed messaging key before encrypted messages can be exchanged.';
      });
    }catch(_){
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _thread=null;_participants=const [];_messages=const [];
        _loading=false;_cryptoReady=false;
        _error='Circle messaging is unavailable. Verify membership, '
          'privacy and individual Circle consent.';
      });
    }
  }
  void _playVideo(Uint8List bytes){
    Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitPrivateChatVideoViewer(bytes:bytes)));
  }

  Future<void> _more() async {
    final thread=_thread;
    if(thread==null)return;
    await const OrbitMessagingConversationActions().openCircle(context,
      thread:thread,onClose:()=>Navigator.of(context).maybePop());
  }

  Future<void> _send(String text) async {
    final thread=_thread;
    if(thread==null || !_cryptoReady)throw OrbitIdentityException(
      'Verified group encryption is required.',503);
    final result=await _messenger.sendText(thread,text);
    if(result.queued){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Encrypted Circle message queued, not yet delivered.')));
      throw OrbitIdentityException('Queued, not acknowledged.',503);
    }
    _refreshAfterConfirmedSend();
  }
  Future<void> _sendReply(String targetId,String text) async {
    final thread=_thread;
    if(thread==null||!_cryptoReady)throw OrbitIdentityException(
      'Verified encryption required before replying.',503);
    final outcome=await _messenger.sendReply(
      thread,targetId:targetId,text:text);
    if(!outcome.accepted||outcome.queued)throw OrbitIdentityException(
      'Encrypted reply is queued but not acknowledged.',503);
    _refreshAfterConfirmedSend();
  }

  Future<void> _sendAttachment(File file,String kind,int? duration) async {
    final thread=_thread;
    if(thread==null||!_cryptoReady)throw OrbitIdentityException(
      'Verified encryption required before encrypted media upload.',503);
    final manifest=await _media.stage(conversation:thread,original:file,
      kind:kind,durationMs:duration);
    final outcome=await _messenger.sendMedia(thread,manifest);
    if(outcome.queued)throw OrbitIdentityException(
      'Encrypted media is pending delivery, not yet acknowledged.',503);
    _refreshAfterConfirmedSend();
  }

  Future<void> _react(String messageId,String? selected,
      Map<String,int> counts) async {
    final thread=_thread;
    if(thread==null||!_cryptoReady)throw OrbitIdentityException(
      'Encrypted messaging is unavailable.',503);
    final result=await _messenger.sendReaction(
      thread,targetId:messageId,selected:selected);
    if(!result.accepted||result.queued)throw OrbitIdentityException(
      'Encrypted reaction was queued but not delivered.',503);
  }

  void _refreshAfterConfirmedSend(){
    if(mounted)WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted)unawaited(_load());
    });
  }

  void _videoUnavailable(){
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:Text('Encrypted video calls are not provisioned.')));
  }
  @override
  Widget build(BuildContext context)=>GroupChatScreen(
    title:widget.circleName,participants:_participants,
    memberCount:_participants.length,
    messages:_messages,currentUserId:_owner??'signed-out',
    isOnline:false,
    viewState:_loading?GroupChatViewState.loading:
      _error!=null?GroupChatViewState.error:GroupChatViewState.loaded,
    errorMessage:_error??'Circle chat unavailable.',
    onRetry:_load,onBack:()=>Navigator.of(context).maybePop(),
    onMorePressed:_more,
    onOpenVideo:_playVideo,
    onVideoCall:_videoUnavailable,
    onSendMessage:_send,
    onSendReply:_sendReply,
    onSendMedia:_sendAttachment,
    onMessageReactionChanged:_react,
    liveMode:true,encryptedTransportReady:_cryptoReady,
  );
}
