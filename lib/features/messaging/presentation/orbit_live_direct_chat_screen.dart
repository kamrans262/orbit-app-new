import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../direct_chat/domain/models/direct_chat_models.dart';
import '../../direct_chat/presentation/screens/direct_chat_screen.dart';
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

/// The original direct-chat widget, not a competing screen. Never constructs
/// demo Miami messages or shows a fabricated live-location card.
class OrbitLiveDirectChatScreen extends StatefulWidget {
  const OrbitLiveDirectChatScreen({required this.peerId,required this.peerName,
    super.key,this.messaging,this.coordinator});
  final String peerId,peerName;
  final OrbitMessagingApi? messaging;
  final OrbitMessagingCoordinator? coordinator;
  @override
  State<OrbitLiveDirectChatScreen> createState()=>_OrbitLiveDirectChatScreenState();
}
class _OrbitLiveDirectChatScreenState extends State<OrbitLiveDirectChatScreen>
    with WidgetsBindingObserver{
  late final OrbitMessagingApi _api=widget.messaging??OrbitMessagingApi();
  late final OrbitMessagingCoordinator _messenger=widget.coordinator??
    OrbitMessagingCoordinator(api:_api);
  final OrbitMessagingMediaBridge _media=OrbitMessagingMediaBridge();
  List<DirectChatMessage> _messages=const [];
  List<DirectChatMessage> _olderMessages=const [];
  OrbitConversation? _thread;
  String? _owner;
  bool _loading=true,_cryptoReady=false;
  String? _error;
  Timer? _timer;
  Timer? _typingTimer;
  bool _otherTyping=false;
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
  void dispose(){
    _epoch++;
    _timer?.cancel();
    _typingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed)unawaited(_load());
  }
  String _time(DateTime date) {
    final local=date.toLocal();
    final hour=local.hour>12?local.hour-12:local.hour==0?12:local.hour;
    return hour.toString()+':'+local.minute.toString().padLeft(2,'0');
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
          (error.statusCode!=null&&error.statusCode!>=500)){
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
    try {
      final owner=await _api.owner;
      final thread=await _api.direct(widget.peerId);
      final ready=await _messenger.secureReady();
      List<DirectChatMessage> next=const [];
      if(ready){
        await _retryQueuedCiphertext();
        final history=await _messenger.refresh(thread);
        next=await _renderHistory(history,thread,owner);
        final ids=next.map((item)=>item.id).toSet();
        next=[..._olderMessages.where((item)=>!ids.contains(item.id)),
          ...next]..sort((a,b)=>a.createdAt.compareTo(b.createdAt));
      }
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _owner=owner;_thread=thread;_cryptoReady=ready;
        _messages=next;_loading=false;
        _error=ready?null:'The secure messaging protocol has not yet been '
          'verified on this device. No messages can be sent or decrypted.';
      });
    }on OrbitMessagingSecurityException{
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _loading=false;_cryptoReady=false;_thread=null;
        _messages=const [];
        _olderMessages=const [];
        _error='An encrypted message could not be verified. '
          'It was not acknowledged or deleted. Reconnect to retry safely.';
      });
    }catch(_){
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _loading=false;_cryptoReady=false;_thread=null;
        _messages=const [];
        _olderMessages=const [];
        _error='This conversation is unavailable. Reconnect to verify friendship, '
          'device trust and privacy settings.';
      });
    }
  }
  Future<List<DirectChatMessage>> _renderHistory(
      List<OrbitLocalDecryptedMessage> history,
      OrbitConversation thread,String owner) async {
    final reactionState=OrbitReactionReducer.fold(history,localUser:owner);
    // Only the newest few sent messages need receipt polling on shared
    // hosting. Sender acknowledgements remain different from device
    // delivered and explicit recipient-opt-in read acknowledgements.
    final status=<String,DirectChatDeliveryStatus>{};
    final newest=history.where((e)=>e.senderId==owner &&
      (e.kind=='text'||e.kind=='reply')).toList().reversed.take(5);
    for(final entry in newest){
      try{
        final r=await _api.receipts(thread.id,entry.id);
        final reads=(r['read_users'] as num?)?.toInt()??0;
        final delivered=(r['delivered_devices'] as num?)?.toInt()??0;
        status[entry.id]=reads>0?DirectChatDeliveryStatus.read:
          delivered>0?DirectChatDeliveryStatus.delivered:
            DirectChatDeliveryStatus.sent;
      }catch(_){status[entry.id]=DirectChatDeliveryStatus.sent;}
    }
    final loaded=<DirectChatMessage>[];
    for(final entry in history){
      if(entry.kind=='reaction')continue;
      final reply=entry.kind=='reply'
        ?OrbitEncryptedReply.fromText(entry.text):null;
      final manifest=OrbitEncryptedChatMedia.tryParse(entry.text);
      var type=entry.senderId==owner
        ?DirectChatMessageType.sentText:DirectChatMessageType.receivedText;
      String? text=entry.text;
      if(reply!=null){
        final original=history.where((e)=>e.id==reply.targetId).toList();
        final quote=original.isEmpty?'Original message'
          :original.first.text;
        text='↪ '+(quote.length>60?quote.substring(0,60)+'…':quote)+
          '\n'+reply.text;
      }
      Uint8List? bytes;
      Duration? audioLength;
      if(manifest!=null){
        try{
          if(manifest.kind!='video'){
            bytes=await _media.open(manifest);
          }
          if(manifest.kind=='image'){
            type=entry.senderId==owner
              ?DirectChatMessageType.sentImage:DirectChatMessageType.receivedImage;
          }else if(manifest.kind=='voice'){
            type=entry.senderId==owner
              ?DirectChatMessageType.sentAudio:DirectChatMessageType.receivedAudio;
            audioLength=Duration(milliseconds:manifest.durationMs??1000);
          }else {
            type=DirectChatMessageType.futureVideo;
          }
          text=null;
        }catch(_){
          // Never render a private storage path, raw media manifest or
          // public URL when recipient access or key is revoked.
          type=entry.senderId==owner
            ?DirectChatMessageType.sentText:DirectChatMessageType.receivedText;
          text='Encrypted media is no longer available.';
        }
      }
      loaded.add(DirectChatMessage(
        id:entry.id,conversationId:thread.id,
        readEnvelopeId:entry.envelopeId,
        type:type,senderId:entry.senderId,
        senderName:entry.senderId==owner?'You':widget.peerName,
        isMine:entry.senderId==owner,text:text,
        audioBytes:manifest?.kind=='voice'?bytes:null,
        audioDuration:audioLength,
        imageBytes:manifest?.kind=='image'?bytes:null,
        videoMediaId:manifest?.kind=='video'?manifest!.mediaId:null,
        reactions:reactionState[entry.id]?.counts??const <String,int>{},
        selectedReaction:reactionState[entry.id]?.selected,
        timestamp:_time(entry.createdAt),createdAt:entry.createdAt,
        showDeliveryStatus:entry.senderId==owner,
        deliveryStatus:entry.senderId==owner
          ?status[entry.id]??DirectChatDeliveryStatus.sent
          :DirectChatDeliveryStatus.delivered));
    }
    return loaded;
  }

  Future<List<DirectChatMessage>> _loadOlder() async {
    final thread=_thread;
    final owner=_owner;
    if(thread==null||owner==null||!_cryptoReady){
      return const <DirectChatMessage>[];
    }
    final raw=await _messenger.loadOlder(thread);
    if(!mounted||raw.isEmpty)return const <DirectChatMessage>[];
    final rendered=await _renderHistory(raw,thread,owner);
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
    await const OrbitMessagingConversationActions().openDirect(context,
      thread:thread,peerId:widget.peerId,
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
      onError:(_){/* Respect Ghost Mode and server typing opt-out. */}));
  }

  Future<void> _pollTyping() async {
    final thread=_thread;
    if(thread==null||!_cryptoReady||_checkingTyping)return;
    _checkingTyping=true;
    try{
      final r=await _api.typingNow(thread.id);
      final ids=r['typing_user_ids'];
      final isTyping=ids is List && ids.contains(widget.peerId);
      if(mounted && _otherTyping!=isTyping){
        setState(()=>_otherTyping=isTyping);
      }
    }catch(_){
      if(mounted && _otherTyping)setState(()=>_otherTyping=false);
    }finally{
      _checkingTyping=false;
    }
  }

  Future<void> _send(DirectChatMessage message) async {
    final thread=_thread;
    if(thread==null || !_cryptoReady){
      throw OrbitIdentityException('Encrypted messaging is unavailable.',503);
    }
    OrbitMessagingSendResult result;
    if(message.type==DirectChatMessageType.sentImage){
      final path=message.imageUrl;
      if(path==null)throw OrbitIdentityException(
        'Image is unavailable for encrypted upload.',422);
      final manifest=await _media.stage(conversation:thread,
        original:File(path),kind:'image');
      result=await _messenger.sendMedia(thread,manifest);
    }else if(message.type==DirectChatMessageType.futureVideo){
      final path=message.videoUrl;
      if(path==null||message.videoDuration==null){
        throw OrbitIdentityException('Video is unavailable.',422);
      }
      final manifest=await _media.stage(conversation:thread,
        original:File(path),kind:'video',
        durationMs:message.videoDuration!.inMilliseconds);
      result=await _messenger.sendMedia(thread,manifest);
    }else if(message.type==DirectChatMessageType.sentAudio){
      final path=message.audioUrl;
      if(path==null)throw OrbitIdentityException(
        'Voice recording is unavailable.',422);
      final recording=File(path);
      try{
        final manifest=await _media.stage(conversation:thread,
          original:recording,kind:'voice',
          durationMs:message.audioDuration?.inMilliseconds);
        result=await _messenger.sendMedia(thread,manifest);
      }finally{
        await OrbitChatVoiceRecorder.discardTemporaryCapture(recording);
      }
    }else if(message.replyToId!=null){
      result=await _messenger.sendReply(thread,
        targetId:message.replyToId!,text:message.text??'');
    }else{
      result=await _messenger.sendText(thread,message.text??'');
    }
    if(result.queued){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Encrypted message queued offline; not yet delivered.')));
      throw OrbitIdentityException('Queued, not acknowledged.',503);
    }
    // Replace the temporary bubble with canonical encrypted server message IDs,
    // making reply/reaction targets valid across every approved device.
    if(mounted)WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted)unawaited(_load());
    });
  }

  Future<void> _react(String id,String? selected,Map<String,int> counts) async {
    final thread=_thread;
    if(thread==null||!_cryptoReady)throw OrbitIdentityException(
      'Encrypted messaging is not available.',503);
    final result=await _messenger.sendReaction(
      thread,targetId:id,selected:selected);
    if(!result.accepted||result.queued)throw OrbitIdentityException(
      'Encrypted reaction was queued but not delivered.',503);
  }

  @override
  Widget build(BuildContext context)=>DirectChatScreen(
    person:DirectChatPerson(id:widget.peerId,name:widget.peerName,
      statusText:_otherTyping?'Typing…':_cryptoReady?'Encrypted conversation':'Secure messaging pending',
      isOnline:false),
    messages:_messages,
    conversationId:_thread?.id??'unavailable',
    currentUserId:_owner??'signed-out',
    viewState:_loading?DirectChatViewState.loading:
      _error!=null?DirectChatViewState.error:DirectChatViewState.loaded,
    errorMessage:_error??'This conversation is unavailable.',
    onRetry:_load,onBack:()=>Navigator.of(context).maybePop(),
    onMorePressed:_more,
    onOpenVideo:_playVideo,
    onTypingChanged:_setTyping,
    onMessageViewed:_viewed,
    onSendMessage:_send,
    onReactionChanged:_react,
    liveMode:true,encryptedTransportReady:_cryptoReady,
    hasMoreOlder:_cryptoReady && _owner!=null && _thread!=null &&
      _messenger.hasOlderMessages(_owner!,_thread!.id),
    onLoadOlder:_loadOlder,
  );
}
