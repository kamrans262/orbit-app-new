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
import '../data/orbit_messaging_local_vault.dart';
import '../data/orbit_messaging_models.dart';
import '../data/orbit_messaging_media_bridge.dart';
import '../data/orbit_messaging_reactions.dart';
import '../data/orbit_messaging_replies.dart';
import '../../../core/navigation/app_fade_slide_page_route.dart';
import 'orbit_chat_voice_recorder.dart';
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
  List<GroupChatMessage> _olderMessages=const [];
  List<GroupParticipant> _participants=const [];
  OrbitConversation? _thread;
  String? _owner;
  bool _loading=true,_cryptoReady=false;
  String? _error;
  Timer? _timer;
  Timer? _typingTimer;
  int _typingCount=0;
  bool _checkingTyping=false;
  int _epoch=0;
  DateTime? _lastOutboxRetry;
  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _typingTimer=Timer.periodic(const Duration(seconds:4),(_){
      if(!mounted || ModalRoute.of(context)?.isCurrent!=true ||
          WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed)return;
      unawaited(_pollTyping());
    });
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
    _typingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  String _time(DateTime date){
    final local=date.toLocal(),h=local.hour;
    return (h%12==0?12:h%12).toString()+':'+local.minute.toString().padLeft(2,'0')
      +(h>=12?' PM':' AM');
  }
  Future<void> _retryQueuedCiphertext() async {
    final now=DateTime.now();
    if(_lastOutboxRetry!=null &&
        now.difference(_lastOutboxRetry!)<const Duration(minutes:1))return;
    _lastOutboxRetry=now;
    OrbitMessagingRetryResult outcome;
    try{
      outcome=await _messenger.retryPending();
    }on OrbitIdentityException catch(error){
      if(error.statusCode==null||error.statusCode==408||
          error.statusCode==429||
          (error.statusCode!=null&&error.statusCode! >= 500)){
        // The encrypted queue is retained on transient network failures.
        return;
      }
      rethrow;
    }
    if(outcome.needsReview>0 && mounted &&
        ModalRoute.of(context)?.isCurrent==true){
      // Keep failed ciphertext in the encrypted local queue. Never mark it
      // delivered or automatically re-encrypt after consent/key revocation.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content:Text('Some queued encrypted messages need review '
          'before they can be delivered.')));
    }
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
        await _retryQueuedCiphertext();
        final history=await _messenger.refresh(conversation);
        next=await _renderHistory(history,conversation,owner,names);
        final redacted=_messenger.redactedMessageIds(owner,conversation.id);
        _olderMessages=_olderMessages.where(
          (item)=>!redacted.contains(item.id)).toList(growable:false);
        final ids=next.map((item)=>item.id).toSet();
        next=[..._olderMessages.where((item)=>!ids.contains(item.id)),
          ...next]..sort((a,b)=>a.createdAt.compareTo(b.createdAt));
      }
      if(!mounted||epoch!=_epoch)return;
      if(!ready)_olderMessages=const [];
      setState((){
        _thread=conversation;_owner=owner;
        _participants=people;_messages=next;_cryptoReady=ready;
        _loading=false;
        _error=ready?null:'This Circle requires verified end-to-end encryption '
          'and a reviewed messaging key before encrypted messages can be exchanged.';
      });
    }on OrbitMessagingSecurityException{
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _thread=null;_participants=const [];_messages=const [];
        _olderMessages=const [];
        _loading=false;_cryptoReady=false;
        _error='A Circle message could not be verified. '
          'It was not acknowledged or deleted. Reconnect to retry safely.';
      });
    }catch(_){
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _thread=null;_participants=const [];_messages=const [];
        _olderMessages=const [];
        _loading=false;_cryptoReady=false;
        _error='Circle messaging is unavailable. Verify membership, '
          'privacy and individual Circle consent.';
      });
    }
  }
  Future<List<GroupChatMessage>> _renderHistory(
      List<OrbitLocalDecryptedMessage> history,
      OrbitConversation thread,String owner,Map<String,String> names) async {
    final reactionState=OrbitReactionReducer.fold(history,localUser:owner);
    final readNames=<String,List<String>>{};
    final deliveredDevices=<String,int>{};
    // Read metadata is filtered on the server against each recipient's
    // current consent, privacy choice, and Circle membership.
    final recent=history.where((entry)=>
      entry.senderId==owner && !entry.id.startsWith('local-') &&
      entry.kind!='reaction').toList()
      ..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
    for(final entry in recent.take(5)){
      try{
        final receipt=await _api.receipts(thread.id,entry.id);
        final ids=receipt['read_recipient_ids'];
        readNames[entry.id]=ids is List
          ?ids.whereType<String>().map((id)=>
            names[id]??'Circle member').toList(growable:false)
          :const <String>[];
        deliveredDevices[entry.id]=
          (receipt['delivered_devices'] as num?)?.toInt()??0;
      }catch(_){
        // An unavailable receipt never proves delivery or reading.
      }
    }
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
          if(manifest.kind!='video'){
            bytes=await _media.open(manifest);
          }
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
        readEnvelopeId:entry.envelopeId,
        senderName:entry.senderId==owner
          ?'You':names[entry.senderId]??'Circle member',
        isMine:entry.senderId==owner,text:text,
        imageBytes:manifest?.kind=='image'?bytes:null,
        videoMediaId:manifest?.kind=='video'?manifest!.mediaId:null,
        audioBytes:manifest?.kind=='voice'?bytes:null,
        audioDuration:audioLength,
        reactions:reactionState[entry.id]?.counts??const <String,int>{},
        selectedReaction:reactionState[entry.id]?.selected,
        readRecipientNames:readNames[entry.id]??const <String>[],
        deliveredDevices:deliveredDevices[entry.id]??0,
        isQueued:entry.id.startsWith('local-'),
        timestamp:_time(entry.createdAt),createdAt:entry.createdAt));
    }
    return loaded;
  }

  Future<List<GroupChatMessage>> _loadOlder() async {
    final thread=_thread;
    final owner=_owner;
    if(thread==null||owner==null||!_cryptoReady){
      return const <GroupChatMessage>[];
    }
    List<OrbitLocalDecryptedMessage> raw;
    try{
      raw=await _messenger.loadOlder(thread);
    }on OrbitIdentityException catch(error){
      if(!mounted)return const <GroupChatMessage>[];
      if(error.statusCode==401||error.statusCode==403||
          error.statusCode==404||error.statusCode==409){
        // Revoked access and failed authentication must clear stale bubbles.
        setState((){
          _cryptoReady=false;_thread=null;
          _messages=const [];_olderMessages=const [];
          _error='Earlier encrypted messages cannot be verified. '
            'Reconnect to check permissions and message keys.';
        });
      }else{
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content:Text('Earlier messages are unavailable. '
            'Reconnect and scroll up to retry.')));
      }
      return const <GroupChatMessage>[];
    }
    if(!mounted||raw.isEmpty)return const <GroupChatMessage>[];
    final names={for(final member in _participants)member.id:member.name};
    final rendered=await _renderHistory(raw,thread,owner,names);
    final known={..._olderMessages.map((item)=>item.id),
      ..._messages.map((item)=>item.id)};
    _olderMessages=[...rendered.where((item)=>!known.contains(item.id)),
      ..._olderMessages];
    return rendered;
  }

  Future<void> _playVideo(String mediaId) async {
    try{
      final bytes=await _media.open(OrbitEncryptedChatMedia(
        mediaId:mediaId,kind:'video',mime:'video/mp4',durationMs:null));
      if(!mounted)return;
      await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
        builder:(_)=>OrbitPrivateChatVideoViewer(bytes:bytes)));
    }catch(_){
      if(mounted)ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content:Text('Encrypted video is unavailable or exceeds the preview limit.')));
    }
  }

  Future<void> _more() async {
    final thread=_thread;
    if(thread==null)return;
    await const OrbitMessagingConversationActions().openCircle(context,
      thread:thread,
      evidenceCandidates:_messages.where((message)=>
        !message.id.startsWith('local-') &&
        (message.type==GroupChatMessageType.receivedText ||
         message.type==GroupChatMessageType.sentText) &&
        message.text!=null && message.text!.trim().isNotEmpty
      ).map<OrbitReportableMessage>((message)=>(
        id:message.id,text:message.text!.trim())).toList(growable:false),
      onClose:()=>Navigator.of(context).maybePop());
  }

  void _viewed(String envelopeId){
    final thread=_thread;
    if(thread==null||!_cryptoReady)return;
    unawaited(_messenger.viewed(thread,envelopeId,
      const Duration(milliseconds:700)).catchError((_){
        // The server alone enforces the user's read-receipt privacy opt-out.
      }));
  }

  void _setTyping(bool active){
    final thread=_thread;
    if(thread==null||!_cryptoReady)return;
    unawaited(_api.typing(thread.id,active).then<void>((_) {},
      onError:(_){/* Respect Circle Ghost Mode/consent. */}));
  }

  Future<void> _pollTyping() async {
    final thread=_thread;
    if(thread==null||!_cryptoReady||_checkingTyping)return;
    _checkingTyping=true;
    try{
      final r=await _api.typingNow(thread.id);
      final ids=r['typing_user_ids'];
      final count=ids is List?ids.length:0;
      if(mounted && _typingCount!=count){
        setState(()=>_typingCount=count);
      }
    }catch(_){
      if(mounted && _typingCount!=0)setState(()=>_typingCount=0);
    }finally{
      _checkingTyping=false;
    }
  }

  Future<void> _send(String text) async {
    final thread=_thread;
    if(thread==null || !_cryptoReady)throw OrbitIdentityException(
      'Verified group encryption is required.',503);
    final result=await _messenger.sendText(thread,text);
    if(result.queued){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Encrypted Circle message queued, not yet delivered.')));
      if(result.clientId==null)throw OrbitMessagingSecurityException(
        'Encrypted queue has no stable retry ID.',503);
      throw OrbitQueuedMessageException(result.clientId!);
    }
    _refreshAfterConfirmedSend();
  }
  Future<void> _sendReply(String targetId,String text) async {
    final thread=_thread;
    if(thread==null||!_cryptoReady)throw OrbitIdentityException(
      'Verified encryption required before replying.',503);
    final outcome=await _messenger.sendReply(
      thread,targetId:targetId,text:text);
    if(outcome.queued){
      if(outcome.clientId==null)throw OrbitMessagingSecurityException(
        'Encrypted queue has no stable retry ID.',503);
      throw OrbitQueuedMessageException(outcome.clientId!);
    }
    if(!outcome.accepted)throw OrbitIdentityException(
      'Encrypted reply was not acknowledged.',503);
    _refreshAfterConfirmedSend();
  }

  Future<void> _sendAttachment(File file,String kind,int? duration) async {
    final thread=_thread;
    if(thread==null||!_cryptoReady)throw OrbitIdentityException(
      'Verified encryption required before encrypted media upload.',503);
    try{
      final manifest=await _media.stage(conversation:thread,original:file,
        kind:kind,durationMs:duration);
      final outcome=await _messenger.sendMedia(thread,manifest);
      if(outcome.queued){
        if(outcome.clientId==null)throw OrbitMessagingSecurityException(
          'Encrypted queue has no stable retry ID.',503);
        throw OrbitQueuedMessageException(outcome.clientId!);
      }
      _refreshAfterConfirmedSend();
    }finally{
      if(kind=='voice'){
        await OrbitChatVoiceRecorder.discardTemporaryCapture(file);
      }
    }
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
    onTypingChanged:_setTyping,
    onMessageViewed:_viewed,
    typingNotice:_typingCount>0
      ?(_typingCount==1?'A member is typing…':'Members are typing…')
      :null,
    onVideoCall:_videoUnavailable,
    onSendMessage:_send,
    onSendReply:_sendReply,
    onSendMedia:_sendAttachment,
    onMessageReactionChanged:_react,
    liveMode:true,encryptedTransportReady:_cryptoReady,
    hasMoreOlder:_cryptoReady && _owner!=null && _thread!=null &&
      _messenger.hasOlderMessages(_owner!,_thread!.id),
    onLoadOlder:_loadOlder,
  );
}
