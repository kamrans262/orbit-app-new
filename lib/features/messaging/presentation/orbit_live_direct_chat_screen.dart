import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/data/orbit_identity_client.dart';
import '../../../direct_chat/domain/models/direct_chat_models.dart';
import '../../../direct_chat/presentation/screens/direct_chat_screen.dart';
import '../data/orbit_messaging_api.dart';
import '../data/orbit_messaging_coordinator.dart';
import '../data/orbit_messaging_models.dart';

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
  List<DirectChatMessage> _messages=const [];
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
  void dispose(){
    _epoch++;
    _timer?.cancel();
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
  Future<void> _load() async {
    final epoch=++_epoch;
    if(_thread==null && mounted)setState(()=>_loading=true);
    try {
      final owner=await _api.owner;
      final thread=await _api.direct(widget.peerId);
      final ready=await _messenger.secureReady();
      List<DirectChatMessage> next=const [];
      if(ready){
        final history=await _messenger.refresh(thread);
        next=history.map((h)=>DirectChatMessage(
          id:h.id,conversationId:thread.id,
          type:h.senderId==owner
            ?DirectChatMessageType.sentText:DirectChatMessageType.receivedText,
          senderId:h.senderId,senderName:h.senderId==owner?'You':widget.peerName,
          isMine:h.senderId==owner,text:h.text,
          timestamp:_time(h.createdAt),createdAt:h.createdAt,
          deliveryStatus:DirectChatDeliveryStatus.delivered,
        )).toList(growable:false);
      }
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _owner=owner;_thread=thread;_cryptoReady=ready;
        _messages=next;_loading=false;
        _error=ready?null:'The secure messaging protocol has not yet been '
          'verified on this device. No messages can be sent or decrypted.';
      });
    }catch(_){
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _loading=false;_cryptoReady=false;_thread=null;
        _messages=const [];
        _error='This conversation is unavailable. Reconnect to verify friendship, '
          'device trust and privacy settings.';
      });
    }
  }
  Future<void> _send(DirectChatMessage message) async {
    final thread=_thread;
    if(thread==null || !_cryptoReady){
      throw OrbitIdentityException('Encrypted messaging is unavailable.',503);
    }
    final result=await _messenger.sendText(thread,message.text??'');
    if(result.queued){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Encrypted message queued offline; not yet delivered.')));
      throw OrbitIdentityException('Queued, not acknowledged.',503);
    }
  }

  @override
  Widget build(BuildContext context)=>DirectChatScreen(
    person:DirectChatPerson(id:widget.peerId,name:widget.peerName,
      statusText:_cryptoReady?'Encrypted conversation':'Secure messaging pending',
      isOnline:false),
    messages:_messages,
    conversationId:_thread?.id??'unavailable',
    currentUserId:_owner??'signed-out',
    viewState:_loading?DirectChatViewState.loading:
      _error!=null?DirectChatViewState.error:DirectChatViewState.loaded,
    errorMessage:_error??'This conversation is unavailable.',
    onRetry:_load,onBack:()=>Navigator.of(context).maybePop(),
    onSendMessage:_send,
    liveMode:true,encryptedTransportReady:_cryptoReady,
    hasMoreOlder:false,
  );
}
