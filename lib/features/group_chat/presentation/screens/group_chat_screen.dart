import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../../circles/presentation/widgets/orbit_circle_confirmation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/chat/message_reactions.dart';
import '../../../../core/chat/chat_audio_message.dart';
import '../../../../core/chat/multiple_image_message.dart';
import '../../../../core/chat/single_image_message.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/group_chat_models.dart';
import '../widgets/chat_input_bar.dart';
import '../../../messaging/presentation/orbit_chat_voice_recorder.dart';
import '../../../messaging/presentation/orbit_message_visibility_observer.dart';
import '../../../messaging/data/orbit_messaging_models.dart';
import '../widgets/group_chat_header.dart';
import '../widgets/received_image_message.dart';
import '../widgets/received_text_message.dart';
import '../widgets/sent_text_message.dart';
import '../widgets/sent_voice_message.dart';

abstract final class GroupChatScreenKeys {
  static const messageList = Key('group_chat_message_list');
  static const loadingOlder = Key('group_chat_loading_older');
  static const retryButton = Key('group_chat_retry_button');
  static Key message(String id) => Key('group_chat_message_$id');
}

typedef SendGroupMessageCallback = FutureOr<void> Function(String text);
typedef SendGroupMediaCallback = FutureOr<void> Function(File file,String kind,int? durationMs);
typedef SendGroupReplyCallback = FutureOr<void> Function(String targetId,String text);
typedef LoadOlderMessagesCallback = FutureOr<List<GroupChatMessage>> Function();
typedef ReactionChangedCallback = FutureOr<void> Function(
  GroupChatMessage message,
  ChatReactionState reaction,
);
typedef GroupMessageReactionChangedCallback = FutureOr<void> Function(
  String messageId,
  String? selectedReaction,
  Map<String, int> counts,
);

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    required this.title,
    required this.participants,
    required this.memberCount,
    required this.messages,
    required this.onBack,
    required this.onVideoCall,
    this.currentUserId = 'me',
    this.isOnline = true,
    this.viewState = GroupChatViewState.loaded,
    this.errorMessage = 'Unable to load this group chat.',
    this.onRetry,
    this.onSendMessage,
    this.onSendReply,
    this.onSendMedia,
    this.onLoadOlder,
    this.hasMoreOlder = false,
    this.onReactionChanged,
    this.onMessageReactionChanged,
    this.onMorePressed,
    this.onOpenVideo,
    this.onTypingChanged,
    this.onMessageViewed,
    this.onDeleteMessage,
    this.typingNotice,
    this.liveMode = false,
    this.encryptedTransportReady = false,
    super.key,
  });

  factory GroupChatScreen.demo({
    VoidCallback? onBack,
    String title = 'peak seekers',
    int memberCount = 9,
    List<String?>? participantAvatars,
  }) {
    final now = DateTime.now();
    final avatarPaths = participantAvatars == null || participantAvatars.isEmpty
        ? const <String?>[
            'assets/Emma.png',
            'assets/Mike.png',
            'assets/Sophia.png',
          ]
        : participantAvatars;
    final participants = List<GroupParticipant>.generate(
      avatarPaths.length,
      (index) => GroupParticipant(
        id: 'member-$index',
        name: 'Member ${index + 1}',
        avatarPath: avatarPaths[index],
      ),
      growable: false,
    );

    return GroupChatScreen(
      title: title.trim().isEmpty ? 'Group Chat' : title.trim(),
      memberCount: memberCount < participants.length
          ? participants.length
          : memberCount,
      participants: participants,
      messages: <GroupChatMessage>[
        GroupChatMessage(
          id: 'received-1',
          type: GroupChatMessageType.receivedText,
          senderId: 'mike',
          senderName: 'Mike',
          senderAvatar: 'assets/Mike.png',
          isMine: false,
          text: 'Please provide more details about your request',
          timestamp: '7:55 PM',
          createdAt: now.subtract(const Duration(minutes: 17)),
        ),
        GroupChatMessage(
          id: 'voice-1',
          type: GroupChatMessageType.sentVoice,
          senderId: 'me',
          senderName: 'You',
          isMine: true,
          audioUrl: 'assets/audio/group_voice_demo.wav',
          audioDuration: const Duration(seconds: 8),
          timestamp: '7:57 PM',
          createdAt: now.subtract(const Duration(minutes: 15)),
        ),
        GroupChatMessage(
          id: 'image-1',
          type: GroupChatMessageType.receivedImage,
          senderId: 'emma',
          senderName: 'Emma',
          senderAvatar: 'assets/Emma.png',
          isMine: false,
          text: 'Here’s what I created:',
          images: <String>['assets/gallery1.jpg', 'assets/gallery4.jpg'],
          reactionAvatars: <String>['assets/Mike.png', 'assets/Sophia.png'],
          timestamp: '8:05 PM',
          createdAt: now.subtract(const Duration(minutes: 7)),
        ),
        GroupChatMessage(
          id: 'sent-1',
          type: GroupChatMessageType.sentText,
          senderId: 'me',
          senderName: 'You',
          isMine: true,
          text: 'I like it! Let’s make in another style',
          timestamp: '8:12 PM',
          createdAt: now,
        ),
      ],
      onBack: onBack ?? () {},
      onVideoCall: () {},
    );
  }

  final String title;
  final List<GroupParticipant> participants;
  final int memberCount;
  final List<GroupChatMessage> messages;
  final String currentUserId;
  final bool isOnline;
  final GroupChatViewState viewState;
  final String errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback onBack;
  final VoidCallback onVideoCall;
  final SendGroupMessageCallback? onSendMessage;
  final SendGroupReplyCallback? onSendReply;
  final SendGroupMediaCallback? onSendMedia;
  final LoadOlderMessagesCallback? onLoadOlder;
  final bool hasMoreOlder;
  final ReactionChangedCallback? onReactionChanged;
  final GroupMessageReactionChangedCallback? onMessageReactionChanged;
  final VoidCallback? onMorePressed;
  final ValueChanged<String>? onOpenVideo;
  final ValueChanged<bool>? onTypingChanged;
  final ValueChanged<String>? onMessageViewed;
  final FutureOr<void> Function(String messageId)? onDeleteMessage;
  final String? typingNotice;
  final bool liveMode;
  final bool encryptedTransportReady;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  static const Color _chatBackground = Color(0xFFF0EEEB);
  static const double _messageGap = 13;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  late List<GroupChatMessage> _messages;
  bool _loadingOlder = false;
  bool _sendingLiveText=false;
  Timer? _typingTimer;
  bool _typingActive=false;

  GroupChatMessage? _replyTo;

  bool _initialScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _messages = List<GroupChatMessage>.of(widget.messages);
    _messageController.addListener(_typingDidChange);
    _scrollController.addListener(_handleScroll);
    _scheduleInitialScroll();
  }

  @override
  void didUpdateWidget(covariant GroupChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.messages, widget.messages)) {
      _messages = List<GroupChatMessage>.of(widget.messages);
      _scheduleScrollToBottom();
    }
  }

  void _typingDidChange(){
    if(!widget.liveMode||widget.onTypingChanged==null)return;
    final active=_messageController.text.trim().isNotEmpty;
    if(active==_typingActive)return;
    _typingActive=active;
    _typingTimer?.cancel();
    widget.onTypingChanged!(active);
    if(active){
      _typingTimer=Timer.periodic(const Duration(seconds:4),(_){
        if(mounted && _typingActive){
          widget.onTypingChanged?.call(true);
        }
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if(_typingActive)widget.onTypingChanged?.call(false);
    _messageController.removeListener(_typingDidChange);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scheduleInitialScroll() {
    if (_initialScrollScheduled) return;
    _initialScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _handleScroll() async {
    if (!_scrollController.hasClients ||
        _loadingOlder ||
        !widget.hasMoreOlder ||
        widget.onLoadOlder == null ||
        _scrollController.offset > 120) {
      return;
    }

    _loadingOlder = true;
    if (mounted) setState(() {});
    final oldMaxExtent = _scrollController.position.maxScrollExtent;
    final oldOffset = _scrollController.offset;

    try {
      final older = await widget.onLoadOlder!();
      if (!mounted || older.isEmpty) return;
      setState(() => _messages.insertAll(0, older));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final extentDelta =
            _scrollController.position.maxScrollExtent - oldMaxExtent;
        _scrollController.jumpTo(oldOffset + extentDelta);
      });
    } finally {
      _loadingOlder = false;
      if (mounted) setState(() {});
    }
  }

  void _chooseReply(GroupChatMessage message){
    if(widget.liveMode && (message.id.startsWith('local-') ||
        !widget.encryptedTransportReady)){
      _sendError('The encrypted message must finish syncing before replying.');
      return;
    }
    setState(()=>_replyTo=message);
    _messageFocusNode.requestFocus();
  }

  Widget _replyBanner(){
    final target=_replyTo!;
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:20,vertical:8),
      color:const Color(0xFFF0EEEB),
      child:Row(children:[
        const Icon(Icons.reply_rounded,size:20,color:Color(0xFF7C5CFC)),
        const SizedBox(width:10),
        Expanded(child:Text(target.text??'Encrypted attachment',
          maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontFamily:AppTypography.fontFamily,
            fontSize:12,color:Color(0xFF64748B)))),
        IconButton(tooltip:'Cancel reply',
          icon:const Icon(Icons.close_rounded,size:19),
          onPressed:()=>setState(()=>_replyTo=null)),
      ]),
    );
  }

  Future<void> _sendCurrentMessage() async {
    final text=_messageController.text.trim();
    if(text.isEmpty)return;
    final reply=_replyTo;
    if(widget.liveMode && (!widget.encryptedTransportReady ||
        (reply==null?widget.onSendMessage==null:widget.onSendReply==null))) {
      _sendError('Verified encryption is required before sending.');
      return;
    }
    final now=DateTime.now();
    final display=reply==null?text:
      '↪ '+(reply.text??'Encrypted attachment')+'\n'+text;
    final message=GroupChatMessage(
      id:'local-'+now.microsecondsSinceEpoch.toString(),
      type:GroupChatMessageType.sentText,senderId:widget.currentUserId,
      senderName:'You',isMine:true,text:display,
      timestamp:_formatTime(now),createdAt:now,
    );
    if(widget.liveMode){
      if(_sendingLiveText)return;
      _sendingLiveText=true;
      setState(()=>_messages.add(message.copyWith(isSending:true)));
      _scheduleScrollToBottom();
      try{
        if(reply!=null){
          await widget.onSendReply!(reply.id,text);
        }else{
          await widget.onSendMessage!(text);
        }
        if(!mounted)return;
        final index=_messages.indexWhere((m)=>m.id==message.id);
        if(index>=0)setState(()=>_messages[index]=message);
        if(_messageController.text.trim()==text)_messageController.clear();
        setState(()=>_replyTo=null);
      }on OrbitQueuedMessageException catch(queued){
        if(!mounted)return;
        final index=_messages.indexWhere((m)=>m.id==message.id);
        final waiting=message.copyWith(id:'local-'+queued.clientId,
          isSending:false,isQueued:!queued.needsReview,
          isFailed:queued.needsReview);
        setState((){
          if(index>=0){_messages[index]=waiting;}
          else{_messages.add(waiting);}
          _replyTo=null;
        });
        if(_messageController.text.trim()==text)_messageController.clear();
        _scheduleScrollToBottom();
      }catch(_){
        if(!mounted)return;
        setState((){
          _messages.removeWhere((m)=>m.id==message.id);
          _replyTo=reply;
        });
        _sendError('Encrypted message was not confirmed as sent.');
      }finally{
        _sendingLiveText=false;
      }
      return;
    }
    setState((){
      _messages.add(message);
      _replyTo=null;
    });
    _messageController.clear();
    _scheduleScrollToBottom();
    try{
      await widget.onSendMessage?.call(text);
    }catch(_){
      if(mounted)_sendError('Message could not be sent.');
    }
  }
  /// Reuse the approved Circle sheet after long-press reactions.
  /// Deletion is enabled only on the authenticated owner's acknowledged
  /// encrypted message and only after Laravel confirms removal.
  Future<void> _messageOptions(GroupChatMessage message) async{
    if(!mounted)return;
    final canCopy=message.text!=null &&
      message.text!.trim().isNotEmpty && message.text!.length<=22000;
    final canDelete=widget.liveMode && message.isMine &&
      !message.id.startsWith('local-') &&
      widget.encryptedTransportReady &&
      widget.onDeleteMessage!=null;
    if(!canCopy&&!canDelete)return;
    await showOrbitCircleSheet<void>(
      context:context,title:'Message Options',
      builder:(sheet)=>Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          if(canCopy)
            OrbitCircleSheetAction(title:'Copy text',
              icon:Icons.copy_outlined,onTap:() async{
                Navigator.of(sheet).pop();
                await Clipboard.setData(ClipboardData(text:message.text!));
              }),
          if(canDelete)...[
            if(canCopy)const SizedBox(height:10),
            OrbitCircleSheetAction(
              title:'Delete my message',
              icon:Icons.delete_outline,
              destructive:true,
              onTap:() async{
                Navigator.of(sheet).pop();
                if(!mounted)return;
                final approved=await showOrbitCircleConfirmation(
                  context:context,title:'Delete Message?',
                  description:'Remove your encrypted Circle message from '
                    'the authorized mailbox? Devices that already decrypted '
                    'their own copies may retain them.',
                  confirmLabel:'Delete Message',
                  cancelLabel:'Cancel',destructive:true);
                if(!approved||!mounted)return;
                try{
                  await widget.onDeleteMessage!(message.id);
                  if(mounted)setState(()=>_messages.removeWhere(
                    (m)=>m.id==message.id));
                }catch(_){
                  if(mounted)_sendError('Encrypted message was not deleted.');
                }
              }),
          ],
        ],
      ),
    );
  }

  void _sendError(String message){
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content:Text(message)));
  }
  void _showQueuedAttachment(String kind,String clientId,
      {bool needsReview=false}){
    if(!mounted)return;
    final now=DateTime.now();
    setState(()=>_messages.add(GroupChatMessage(
      id:'local-'+clientId,
      type:GroupChatMessageType.sentText,
      senderId:widget.currentUserId,senderName:'You',isMine:true,
      isQueued:!needsReview,isFailed:needsReview,
      text:'Encrypted '+kind+
        (needsReview?' failed · review required':' waiting for connection'),
      timestamp:_formatTime(now),createdAt:now)));
    _scheduleScrollToBottom();
  }

  Future<void> _changeReaction(
    GroupChatMessage message,
    ChatReactionState next,
  ) async {
    if(widget.liveMode && widget.onReactionChanged==null){
      _sendError('Encrypted reactions are not yet available.');
      throw StateError('Encrypted reaction callback is unavailable.');
    }
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index < 0) return;
    final previous = _messages[index];
    setState(() => _messages[index] = previous.copyWith(reactionState: next));
    try {
      await widget.onReactionChanged?.call(message, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages[index] = previous);
    }
  }

  Future<void> _pickSingleImage() async {
    if(widget.liveMode && (!widget.encryptedTransportReady ||
        widget.onSendMedia==null)){
      _sendError('Verified encryption is required for group images.');
      return;
    }
    try{
      final image=await _imagePicker.pickImage(source:ImageSource.gallery,
        imageQuality:90);
      if(!mounted||image==null)return;
      if(widget.liveMode){
        await widget.onSendMedia!(File(image.path),'image',null);
      }
      if(!mounted)return;
      final now=DateTime.now();
      setState(()=>_messages.add(GroupChatMessage(
        id:'image-'+now.microsecondsSinceEpoch.toString(),
        type:GroupChatMessageType.sentImage,senderId:widget.currentUserId,
        senderName:'You',isMine:true,images:[image.path],
        timestamp:_formatTime(now),createdAt:now)));
      _scheduleScrollToBottom();
    }on OrbitQueuedMessageException catch(queued){
      _showQueuedAttachment('image',queued.clientId,
        needsReview:queued.needsReview);
    }catch(_){
      if(mounted)_sendError('Encrypted image was not confirmed as sent.');
    }
  }

  Future<void> _pickMultipleImages() async {
    if(widget.liveMode && (!widget.encryptedTransportReady ||
        widget.onSendMedia==null)){
      _sendError('Verified encryption is required for group images.');
      return;
    }
    try{
      final images=await _imagePicker.pickMultiImage(imageQuality:90);
      if(!mounted||images.isEmpty)return;
      for(final image in images){
        if(widget.liveMode){
          await widget.onSendMedia!(File(image.path),'image',null);
        }
        if(!mounted)return;
        final now=DateTime.now();
        setState(()=>_messages.add(GroupChatMessage(
          id:'image-'+now.microsecondsSinceEpoch.toString(),
          type:GroupChatMessageType.sentImage,
          senderId:widget.currentUserId,senderName:'You',
          isMine:true,images:[image.path],
          timestamp:_formatTime(now),createdAt:now)));
      }
      _scheduleScrollToBottom();
    }on OrbitQueuedMessageException catch(queued){
      _showQueuedAttachment('image',queued.clientId,
        needsReview:queued.needsReview);
    }catch(_){
      if(mounted)_sendError('One or more encrypted images were not confirmed.');
    }
  }

  Future<void> _pickVideo() async {
    if(widget.liveMode && (!widget.encryptedTransportReady ||
        widget.onSendMedia==null)){
      _sendError('Verified encryption is required for group videos.');
      return;
    }
    VideoPlayerController? inspector;
    try{
      final item=await _imagePicker.pickVideo(source:ImageSource.gallery);
      if(!mounted||item==null)return;
      final file=File(item.path);
      if(await file.length()>250*1024*1024){
        throw StateError('Video exceeds the 250 MB limit.');
      }
      inspector=VideoPlayerController.file(file);
      await inspector.initialize();
      final duration=inspector.value.duration;
      if(duration<=Duration.zero||duration>const Duration(seconds:60)){
        throw StateError('Video must be 60 seconds or shorter.');
      }
      if(widget.liveMode){
        await widget.onSendMedia!(file,'video',duration.inMilliseconds);
      }
      if(!mounted)return;
      final now=DateTime.now();
      setState(()=>_messages.add(GroupChatMessage(
        id:'local-'+now.microsecondsSinceEpoch.toString(),
        type:GroupChatMessageType.futureVideo,
        senderId:widget.currentUserId,senderName:'You',
        isMine:true,timestamp:_formatTime(now),createdAt:now)));
      _scheduleScrollToBottom();
    }on OrbitQueuedMessageException catch(queued){
      _showQueuedAttachment('video',queued.clientId,
        needsReview:queued.needsReview);
    }catch(_){
      if(mounted)_sendError('Encrypted video was not confirmed as sent.');
    }finally{
      await inspector?.dispose();
    }
  }

  Future<void> _recordVoice() async {
    if(widget.liveMode && (!widget.encryptedTransportReady ||
        widget.onSendMedia==null)){
      _sendError('Verified encryption is required for group voice.');
      return;
    }
    final recording=await OrbitChatVoiceRecorder.open(context);
    if(recording==null||!mounted)return;
    try{
      // The live encrypted upload discards the temporary source file when
      // it finishes. Load preview bytes before that cleanup occurs.
      final bytes=Uint8List.fromList(await recording.file.readAsBytes());
      if(widget.liveMode){
        await widget.onSendMedia!(recording.file,'voice',recording.durationMs);
      }
      if(!mounted)return;
      final now=DateTime.now();
      setState(()=>_messages.add(GroupChatMessage(
        id:'voice-'+now.microsecondsSinceEpoch.toString(),
        type:GroupChatMessageType.sentVoice,
        senderId:widget.currentUserId,senderName:'You',isMine:true,
        audioBytes:bytes,audioDuration:Duration(milliseconds:recording.durationMs),
        timestamp:_formatTime(now),createdAt:now)));
      _scheduleScrollToBottom();
    }on OrbitQueuedMessageException catch(queued){
      _showQueuedAttachment('voice',queued.clientId,
        needsReview:queued.needsReview);
    }catch(_){
      if(mounted)_sendError('Encrypted voice was not confirmed as sent.');
    }finally{
      try{if(await recording.file.exists())await recording.file.delete();}catch(_){}
    }
  }

  Future<void> _pickSticker() async {
    if(widget.liveMode && (!widget.encryptedTransportReady || widget.onSendMessage==null)){
      _sendError('Verified encryption is required for stickers.');return;
    }
    final sticker = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _GroupSticker(
                value: '\u{2764}\u{FE0F}',
                icon: Icons.favorite_rounded,
              ),
              _GroupSticker(value: '\u{1F44D}', icon: Icons.thumb_up_rounded),
              _GroupSticker(
                value: '\u{1F602}',
                icon: Icons.sentiment_very_satisfied_rounded,
              ),
              _GroupSticker(
                value: '\u{1F389}',
                icon: Icons.celebration_rounded,
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || sticker == null) return;
    final now = DateTime.now();
    if(widget.liveMode){
      try{await widget.onSendMessage!(sticker);}
      on OrbitQueuedMessageException catch(queued){
        _showQueuedAttachment('sticker',queued.clientId,
        needsReview:queued.needsReview);
        return;
      }catch(_){if(mounted)_sendError('Encrypted sticker was not sent.');return;}
      if(!mounted)return;
    }
    setState(() {
      _messages.add(
        GroupChatMessage(
          id: 'sticker-${now.microsecondsSinceEpoch}',
          type: GroupChatMessageType.sentText,
          senderId: widget.currentUserId,
          senderName: 'You',
          isMine: true,
          text: sticker,
          timestamp: _formatTime(now),
          createdAt: now,
        ),
      );
    });
    _scheduleScrollToBottom();
  }

  Future<void> _changeMessageReaction(
    GroupChatMessage message,
    ChatReactionKind? selected,
    Map<ChatReactionKind, int> counts,
  ) async {
    if(widget.liveMode && message.id.startsWith('local-')){
      _sendError('Wait until the encrypted message is synced.');
      throw StateError('Local message ID is not a server message ID.');
    }
    if(widget.liveMode && widget.onMessageReactionChanged==null){
      _sendError('Encrypted reactions are not yet available.');
      throw StateError('Encrypted reaction callback is unavailable.');
    }
    await widget.onMessageReactionChanged?.call(
      message.id,
      selected?.backendValue,
      <String, int>{
        for (final entry in counts.entries) entry.key.backendValue: entry.value,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _chatBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: <Widget>[
            GroupChatHeader(
              title: widget.title,
              participants: widget.participants,
              memberCount: widget.memberCount,
              isOnline: widget.isOnline,
              onBack: widget.onBack,
              onVideoCall: widget.onVideoCall,
              onMore:widget.onMorePressed,
            ),
            Expanded(child: _buildBody()),
            if(widget.liveMode && widget.typingNotice!=null)
              Padding(
                padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),
                child:Text(widget.typingNotice!,
                  style:const TextStyle(fontFamily:AppTypography.fontFamily,
                    fontSize:12,color:Color(0xFF7C5CFC))),
              ),
            if(widget.liveMode && !widget.encryptedTransportReady)
              const Padding(
                padding:EdgeInsets.symmetric(horizontal:20,vertical:8),
                child:Text('This Circle chat requires verified end-to-end encryption.',
                  textAlign:TextAlign.center,
                  style:TextStyle(fontFamily:AppTypography.fontFamily,
                    fontSize:12,color:Color(0xFF64748B))),
              ),
            if(_replyTo!=null)_replyBanner(),
            SafeArea(
              top: false,
              child: ChatInputBar(
                controller: _messageController,
                focusNode: _messageFocusNode,
                onSend: _sendCurrentMessage,
                onPickSingleImage: _pickSingleImage,
                onPickMultipleImages: _pickMultipleImages,
                onPickSticker: _pickSticker,
                onRecordVoice:_recordVoice,
                onPickVideo:_pickVideo,
                enabled: !widget.liveMode || widget.encryptedTransportReady,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (widget.viewState) {
      case GroupChatViewState.loading:
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        );
      case GroupChatViewState.error:
        return _ErrorState(
          message: widget.errorMessage,
          onRetry: widget.onRetry,
        );
      case GroupChatViewState.loaded:
        if (_messages.isEmpty) {
          return const _EmptyState();
        }
        return ListView.separated(
          key: GroupChatScreenKeys.messageList,
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(15, 17.5, 15, 17.5),
          itemCount: _messages.length + (_loadingOlder ? 1 : 0),
          separatorBuilder: (context, index) =>
              const SizedBox(height: _messageGap),
          itemBuilder: (context, index) {
            if (_loadingOlder && index == 0) {
              return const Center(
                key: GroupChatScreenKeys.loadingOlder,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final adjustedIndex = index - (_loadingOlder ? 1 : 0);
            final message = _messages[adjustedIndex];
            return KeyedSubtree(
              key: GroupChatScreenKeys.message(message.id),
              child: GestureDetector(
                behavior:HitTestBehavior.translucent,
                onHorizontalDragEnd:(velocity){
                  if((velocity.primaryVelocity??0)>250){
                    _chooseReply(message);
                  }
                },
                child: MessageReactionRegion(
                messageId: message.id,
                isMine: message.isMine,
                onMessageOptions:()=>_messageOptions(message),
                initialSelected:_reactionFromValue(message.selectedReaction),
                initialCounts:_reactionCountValues(message.reactions),
                onChanged: (id, selected, counts) =>
                    _changeMessageReaction(message, selected, counts),
                child:widget.liveMode &&
                  !message.isMine &&
                  message.readEnvelopeId!=null &&
                  widget.onMessageViewed!=null
                  ?OrbitMessageVisibilityObserver(
                    onDwell:()=>widget.onMessageViewed!(
                      message.readEnvelopeId!),
                    child:_buildMessageWithReceipts(message))
                  :_buildMessageWithReceipts(message),
                ),
              ),
            );
          },
        );
    }
  }

  Widget _buildMessageWithReceipts(GroupChatMessage message) {
    final bubble=_buildMessage(message);
    if(!widget.liveMode||!message.isMine)return bubble;
    final readers=message.readRecipientNames;
    if(!message.isQueued && !message.isSending && !message.isFailed &&
       readers.isEmpty && message.deliveredDevices<=0)return bubble;
    final visible=readers.take(3).join(', ');
    final additional=readers.length>3?readers.length-3:0;
    final receipt=message.isFailed
      ?'Failed · review encryption before retry'
      :message.isSending
      ?'Sending'
      :message.isQueued
        ?'Waiting for connection'
        :readers.isNotEmpty
        ?'Read by $visible'+(additional>0?' +$additional more':'')
        :'Delivered to ${message.deliveredDevices} device'+
          (message.deliveredDevices==1?'':'s');
    return Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        bubble,
        Align(
          alignment:Alignment.centerRight,
          child:Padding(
            padding:const EdgeInsets.only(top:4,right:6),
            child:Text(receipt,maxLines:2,
              overflow:TextOverflow.ellipsis,
              style:const TextStyle(
                fontFamily:AppTypography.fontFamily,fontSize:12,
                color:AppColors.textMuted)),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(GroupChatMessage message) {
    switch (message.type) {
      case GroupChatMessageType.receivedText:
        return ReceivedTextMessage(message: message);
      case GroupChatMessageType.sentText:
        return SentTextMessage(message: message);
      case GroupChatMessageType.sentVoice:
      case GroupChatMessageType.receivedVoice:
        if(message.audioBytes!=null){
          return ChatAudioMessage(audioSource:'',audioBytes:message.audioBytes,
            duration:message.audioDuration??const Duration(seconds:1),
            timestamp:message.timestamp,isMine:message.isMine);
        }
        if(message.type==GroupChatMessageType.sentVoice){
          return SentVoiceMessage(message:message);
        }
        return ChatAudioMessage(audioSource:'',
          duration:message.audioDuration??const Duration(seconds:1),
          timestamp:message.timestamp,isMine:false);
      case GroupChatMessageType.receivedImage:
        if(message.imageBytes!=null){
          return SingleImageMessage(
            source:'',bytes:message.imageBytes,
            timestamp:message.timestamp,isMine:false);
        }
        return ReceivedImageMessage(
          message: message,
          onReactionChanged: (reaction) => _changeReaction(message, reaction),
        );
      case GroupChatMessageType.sentImage:
        return SingleImageMessage(
          source: message.images.isEmpty ? '' : message.images.first,
          bytes:message.imageBytes,
          timestamp: message.timestamp,
          isMine: true,
        );
      case GroupChatMessageType.receivedMultiImage:
      case GroupChatMessageType.sentMultiImage:
        return MultipleImageMessage(
          sources: message.images,
          timestamp: message.timestamp,
          isMine: message.isMine,
        );
      case GroupChatMessageType.futureAudio:
      case GroupChatMessageType.futureVideo:
      case GroupChatMessageType.futureFile:
      case GroupChatMessageType.futureSystemMessage:
        return _FutureMessagePlaceholder(message: message,
          onTap:message.videoMediaId!=null && widget.onOpenVideo!=null
            ?()=>widget.onOpenVideo!(message.videoMediaId!):null);
    }
  }

  static ChatReactionKind? _reactionFromValue(String? value){
    if(value==null)return null;
    for(final kind in ChatReactionKind.values){
      if(kind.backendValue==value)return kind;
    }
    return null;
  }
  static Map<ChatReactionKind,int> _reactionCountValues(Map<String,int> values){
    final result=<ChatReactionKind,int>{};
    for(final entry in values.entries){
      final kind=_reactionFromValue(entry.key);
      if(kind!=null && entry.value>0)result[kind]=entry.value;
    }
    return result;
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _GroupSticker extends StatelessWidget {
  const _GroupSticker({required this.value, required this.icon});

  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x1FA576F6),
        ),
        child: Icon(icon, color: const Color(0xFF7C3AED)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No messages yet. Start the conversation.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 14),
              TextButton(
                key: GroupChatScreenKeys.retryButton,
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FutureMessagePlaceholder extends StatelessWidget {
  const _FutureMessagePlaceholder({required this.message,this.onTap});

  final GroupChatMessage message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (message.type) {
      GroupChatMessageType.futureAudio => 'Audio message',
      GroupChatMessageType.futureVideo => 'Video message',
      GroupChatMessageType.futureFile => 'File attachment',
      GroupChatMessageType.futureSystemMessage =>
        (message.text ?? 'Group update').trim(),
      _ => 'Message',
    };

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(onTap:onTap,
        borderRadius:BorderRadius.circular(16),
        child:Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xC7FFFFFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          onTap!=null?'▶ '+label:(label.isEmpty ? 'Group update' : label),
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        ),
      ),
    );
  }
}
