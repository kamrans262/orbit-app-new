import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/chat/chat_audio_message.dart';
import '../../../../core/chat/chat_media_image.dart';
import '../../../../core/chat/message_reactions.dart';
import '../../../../core/chat/multiple_image_message.dart';
import '../../../../core/chat/single_image_message.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../domain/models/direct_chat_models.dart';
import '../widgets/direct_chat_input_bar.dart';
import '../widgets/direct_chat_profile_header.dart';
import '../widgets/direct_location_message.dart';
import '../widgets/direct_text_messages.dart';
import '../widgets/live_location_card.dart';
import '../../../welcome/presentation/screens/share_location_screen.dart';
import '../../../messaging/presentation/orbit_chat_voice_recorder.dart';
import '../../../messaging/presentation/orbit_message_visibility_observer.dart';

abstract final class DirectChatScreenKeys {
  static const title = Key('direct_chat_title');
  static const backButton = Key('direct_chat_back_button');
  static const scroll = Key('direct_chat_scroll');
  static const liveLocationCard = Key('direct_chat_live_location_card');
  static const dateSeparator = Key('direct_chat_date_separator');
  static const loadingOlder = Key('direct_chat_loading_older');
  static Key message(String id) => Key('direct_chat_message_$id');
}

typedef DirectSendMessageCallback = FutureOr<void> Function(
  DirectChatMessage message,
);
typedef DirectLoadOlderCallback = FutureOr<List<DirectChatMessage>> Function();
typedef DirectReactionCallback = FutureOr<void> Function(
  String messageId,
  String? selectedReaction,
  Map<String, int> counts,
);

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    required this.person,
    required this.messages,
    this.conversationId = 'direct-demo',
    this.currentUserId = 'me',
    this.viewState = DirectChatViewState.loaded,
    this.errorMessage = 'Unable to load this chat.',
    this.mapImagePath = 'assets/orbit_map.png',
    this.hasMoreOlder = false,
    this.onBack,
    this.onRetry,
    this.onSendMessage,
    this.onLoadOlder,
    this.onReactionChanged,
    this.onViewMap,
    this.onMorePressed,
    this.onOpenVideo,
    this.onTypingChanged,
    this.onMessageViewed,
    this.liveMode = false,
    this.encryptedTransportReady = false,
    super.key,
  });

  factory DirectChatScreen.demo({
    String personName = 'Daisy',
    String? avatarPath = 'assets/Emma.png',
    String? initialMessage,
    VoidCallback? onBack,
  }) {
    final now = DateTime.now();
    final person = DirectChatPerson(
      id: personName.toLowerCase().replaceAll(' ', '-'),
      name: personName.trim().isEmpty ? 'Daisy' : personName.trim(),
      avatarPath: avatarPath,
      statusText: 'Live · Miami Beach',
      isOnline: true,
    );
    final messages = <DirectChatMessage>[
      DirectChatMessage(
        id: 'received-1',
        conversationId: 'direct-demo',
        type: DirectChatMessageType.receivedText,
        senderId: person.id,
        senderName: person.name,
        senderAvatar: person.avatarPath,
        isMine: false,
        text: 'Hey!! Are you heading to South Beach yet? \u{1F30A}',
        timestamp: '9:32',
        createdAt: now.subtract(const Duration(minutes: 9)),
      ),
      DirectChatMessage(
        id: 'sent-1',
        conversationId: 'direct-demo',
        type: DirectChatMessageType.sentText,
        senderId: 'me',
        senderName: 'You',
        isMine: true,
        text: 'Almost! Just grabbing coffee first \u{2615}',
        timestamp: '9:34',
        createdAt: now.subtract(const Duration(minutes: 7)),
      ),
      DirectChatMessage(
        id: 'received-2',
        conversationId: 'direct-demo',
        type: DirectChatMessageType.receivedText,
        senderId: person.id,
        senderName: person.name,
        senderAvatar: person.avatarPath,
        isMine: false,
        text: "haha ok I'm at the Lummus park area — come find me \u{1F601}",
        timestamp: '9:35',
        createdAt: now.subtract(const Duration(minutes: 6)),
      ),
      DirectChatMessage(
        id: 'location-1',
        conversationId: 'direct-demo',
        type: DirectChatMessageType.locationMessage,
        senderId: 'me',
        senderName: 'You',
        isMine: true,
        latitude: 25.7826,
        longitude: -80.1341,
        locationName: 'South Beach',
        mapImagePath: 'assets/orbit_map.png',
        timestamp: '9:36',
        createdAt: now.subtract(const Duration(minutes: 5)),
        reactions: const <String, int>{'\u{2764}\u{FE0F}': 1},
      ),
      DirectChatMessage(
        id: 'received-3',
        conversationId: 'direct-demo',
        type: DirectChatMessageType.receivedText,
        senderId: person.id,
        senderName: person.name,
        senderAvatar: person.avatarPath,
        isMine: false,
        text: 'I can see you on the map! Only 5 min away \u{1F389}',
        timestamp: '9:38',
        createdAt: now.subtract(const Duration(minutes: 3)),
      ),
      DirectChatMessage(
        id: 'sent-2',
        conversationId: 'direct-demo',
        type: DirectChatMessageType.sentText,
        senderId: 'me',
        senderName: 'You',
        isMine: true,
        text: 'On my way! Save me a spot \u{1F3D6}\u{FE0F}',
        timestamp: '9:40',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      DirectChatMessage(
        id: 'received-4',
        conversationId: 'direct-demo',
        type: DirectChatMessageType.receivedText,
        senderId: person.id,
        senderName: person.name,
        senderAvatar: person.avatarPath,
        isMine: false,
        text: "Done! We're at the blue umbrella cluster near 10th \u{1F919}",
        timestamp: '9:41',
        createdAt: now,
      ),
    ];
    final initial = initialMessage?.trim();
    if (initial != null && initial.isNotEmpty) {
      messages.add(
        DirectChatMessage(
          id: 'initial-${now.microsecondsSinceEpoch}',
          conversationId: 'direct-demo',
          type: DirectChatMessageType.sentText,
          senderId: 'me',
          senderName: 'You',
          isMine: true,
          text: initial,
          timestamp: _formatTime(now),
          createdAt: now.add(const Duration(milliseconds: 1)),
        ),
      );
    }
    return DirectChatScreen(person: person, messages: messages, onBack: onBack);
  }

  final DirectChatPerson person;
  final List<DirectChatMessage> messages;
  final String conversationId;
  final String currentUserId;
  final DirectChatViewState viewState;
  final String errorMessage;
  final String mapImagePath;
  final bool hasMoreOlder;
  final VoidCallback? onBack;
  final VoidCallback? onRetry;
  final DirectSendMessageCallback? onSendMessage;
  final DirectLoadOlderCallback? onLoadOlder;
  final DirectReactionCallback? onReactionChanged;
  final VoidCallback? onViewMap;
  final VoidCallback? onMorePressed;
  final ValueChanged<String>? onOpenVideo;
  final ValueChanged<bool>? onTypingChanged;
  final ValueChanged<String>? onMessageViewed;
  final bool liveMode;
  final bool encryptedTransportReady;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  late List<DirectChatMessage> _messages;
  bool _loadingOlder = false;
  Timer? _typingTimer;
  bool _typingActive=false;

  DirectChatMessage? _replyTo;


  @override
  void initState() {
    super.initState();
    _messages = List<DirectChatMessage>.of(widget.messages);
    _messageController.addListener(_typingDidChange);
    _scrollController.addListener(_handleOlderLoad);
  }

  @override
  void didUpdateWidget(covariant DirectChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.messages, widget.messages)) {
      _messages = List<DirectChatMessage>.of(widget.messages);
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
      ..removeListener(_handleOlderLoad)
      ..dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleOlderLoad() async {
    if (!_scrollController.hasClients ||
        _loadingOlder ||
        !widget.hasMoreOlder ||
        widget.onLoadOlder == null ||
        _scrollController.offset > 80) {
      return;
    }
    _loadingOlder = true;
    if (mounted) setState(() {});
    final oldMax = _scrollController.position.maxScrollExtent;
    final oldOffset = _scrollController.offset;
    try {
      final older = await widget.onLoadOlder!();
      if (!mounted || older.isEmpty) return;
      setState(() => _messages.insertAll(0, older));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final delta = _scrollController.position.maxScrollExtent - oldMax;
        _scrollController.jumpTo(oldOffset + delta);
      });
    } finally {
      _loadingOlder = false;
      if (mounted) setState(() {});
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _chooseReply(DirectChatMessage message){
    if(widget.liveMode && (message.id.startsWith('local-') ||
        !widget.encryptedTransportReady)){
      _showError('The encrypted message must finish syncing before replying.');
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
        const Icon(Icons.reply_rounded,color:Color(0xFF7C5CFC),size:20),
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

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if(widget.liveMode &&
      (!widget.encryptedTransportReady || widget.onSendMessage==null)){
      _showError('Verified end-to-end encryption is required before sending.');
      return;
    }
    final message=_newMine(type:DirectChatMessageType.sentText,
      text:text,replyToId:_replyTo?.id);
    if(widget.liveMode){
      try{
        // Do not fabricate a sent bubble: encryption, durable ratchet write
        // and server acknowledgement must all happen first.
        await widget.onSendMessage!(message);
        if(!mounted)return;
        setState(()=>_messages.add(message.copyWith(
          deliveryStatus:DirectChatDeliveryStatus.sent)));
        _messageController.clear();
        setState(()=>_replyTo=null);
        _scrollToLatest();
      }catch(_){
        if(mounted)_showError('Encrypted send failed. No delivery was confirmed.');
      }
      return;
    }
    setState(() => _messages.add(message));
    _messageController.clear();
    setState(()=>_replyTo=null);
    _scrollToLatest();
    try {
      await widget.onSendMessage?.call(message);
    } catch (_) {
      if (!mounted) return;
      _showError('Message could not be sent.');
    }
  }

  Future<void> _openAttachments() async {
    if(widget.liveMode && (!widget.encryptedTransportReady ||
        widget.onSendMessage==null)){
      _showError('Verified encryption is required before attachments.');
      return;
    }
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<_AttachmentChoice>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _AttachmentTile(
                icon: Icons.image_outlined,
                label: 'Single image',
                onTap: () =>
                    Navigator.pop(sheetContext, _AttachmentChoice.singleImage),
              ),
              _AttachmentTile(
                icon: Icons.photo_library_outlined,
                label: 'Multiple images',
                onTap: () => Navigator.pop(
                  sheetContext,
                  _AttachmentChoice.multipleImages,
                ),
              ),
              _AttachmentTile(
                icon: Icons.sentiment_satisfied_alt_rounded,
                label: 'Emoji / sticker',
                onTap: () =>
                    Navigator.pop(sheetContext, _AttachmentChoice.sticker),
              ),
              _AttachmentTile(
                icon:Icons.videocam_outlined,label:'Video message',
                onTap:()=>Navigator.pop(sheetContext,_AttachmentChoice.video),
              ),
              _AttachmentTile(
                icon:Icons.mic_none_rounded,label:'Voice message',
                onTap:()=>Navigator.pop(sheetContext,_AttachmentChoice.voice),
              ),
              const _AttachmentTile(
                icon: Icons.attach_file_rounded,
                label: 'Files (coming next)',
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AttachmentChoice.singleImage:
        await _pickSingleImage();
        break;
      case _AttachmentChoice.multipleImages:
        await _pickMultipleImages();
        break;
      case _AttachmentChoice.sticker:
        await _pickSticker();
        break;
      case _AttachmentChoice.voice:
        await _recordVoice();
        break;
      case _AttachmentChoice.video:
        await _pickVideo();
        break;
    }
  }

  Future<void> _pickSingleImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (!mounted || image == null) return;
      final message = _newMine(
        type: DirectChatMessageType.sentImage,
        imageUrl: image.path,
      );
      if(widget.liveMode){
        await widget.onSendMessage!(message);
        if(!mounted)return;
        setState(()=>_messages.add(message.copyWith(
          deliveryStatus:DirectChatDeliveryStatus.sent)));
      }else{
        setState(() => _messages.add(message));
        await widget.onSendMessage?.call(message);
      }
      _scrollToLatest();
    } catch (_) {
      if (mounted) _showError('Encrypted image could not be sent.');
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 90);
      if (!mounted || images.isEmpty) return;
      final paths = images.map((image) => image.path).toList(growable: false);
      final message = _newMine(
        type: paths.length == 1
            ? DirectChatMessageType.sentImage
            : DirectChatMessageType.sentMultiImage,
        imageUrl: paths.length == 1 ? paths.first : null,
        images: paths,
      );
      if(widget.liveMode){
        // Each photo becomes an independently authorized encrypted M6
        // upload and a signed M13 message, never one unencrypted batch.
        for(final path in paths){
          final each=_newMine(type:DirectChatMessageType.sentImage,
            imageUrl:path);
          await widget.onSendMessage!(each);
          if(!mounted)return;
          setState(()=>_messages.add(each.copyWith(
            deliveryStatus:DirectChatDeliveryStatus.sent)));
        }
      }else{
        setState(() => _messages.add(message));
        await widget.onSendMessage?.call(message);
      }
      _scrollToLatest();
    } catch (_) {
      if (mounted) _showError('One or more encrypted images were not sent.');
    }
  }

  Future<void> _pickSticker() async {
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
            children: const <_StickerChoice>[
              _StickerChoice(
                value: '\u{2764}\u{FE0F}',
                icon: Icons.favorite_rounded,
              ),
              _StickerChoice(value: '\u{1F44D}', icon: Icons.thumb_up_rounded),
              _StickerChoice(
                value: '\u{1F602}',
                icon: Icons.sentiment_very_satisfied_rounded,
              ),
              _StickerChoice(
                value: '\u{1F389}',
                icon: Icons.celebration_rounded,
              ),
              _StickerChoice(value: '\u{2615}', icon: Icons.local_cafe_rounded),
              _StickerChoice(value: '\u{1F30A}', icon: Icons.waves_rounded),
            ],
          ),
        ),
      ),
    );
    if (!mounted || sticker == null) return;
    final message = _newMine(
      type: DirectChatMessageType.sentText,
      text: sticker,
    );
    try{
      if(widget.liveMode){
        if(!widget.encryptedTransportReady||widget.onSendMessage==null){
          throw StateError('Encryption unavailable');
        }
        await widget.onSendMessage!(message);
      }else{
        await widget.onSendMessage?.call(message);
      }
      if(!mounted)return;
      setState(()=>_messages.add(message));
      _scrollToLatest();
    }catch(_){
      if(mounted)_showError('Encrypted sticker was not confirmed.');
    }
  }

  Future<void> _pickVideo() async {
    if(widget.liveMode && (!widget.encryptedTransportReady ||
        widget.onSendMessage==null)){
      _showError('Verified encryption is required for video messages.');
      return;
    }
    VideoPlayerController? inspector;
    try{
      final item=await _imagePicker.pickVideo(source:ImageSource.gallery);
      if(!mounted||item==null)return;
      final file=File(item.path);
      if(await file.length()>250*1024*1024){
        throw StateError('Video is larger than 250 MB.');
      }
      inspector=VideoPlayerController.file(file);
      await inspector.initialize();
      final length=inspector.value.duration;
      if(length<=Duration.zero||length>const Duration(seconds:60)){
        throw StateError('Video must be 60 seconds or shorter.');
      }
      final message=_newMine(type:DirectChatMessageType.futureVideo,
        videoUrl:item.path,videoDuration:length);
      if(widget.liveMode){
        await widget.onSendMessage!(message);
        if(!mounted)return;
        setState(()=>_messages.add(message.copyWith(
          deliveryStatus:DirectChatDeliveryStatus.sent)));
      }else{
        setState(()=>_messages.add(message));
        await widget.onSendMessage?.call(message);
      }
      _scrollToLatest();
    }catch(_){
      if(mounted)_showError('Video was not confirmed as encrypted and sent.');
    }finally{
      await inspector?.dispose();
    }
  }

  Future<void> _recordVoice() async {
    if(widget.liveMode &&
        (!widget.encryptedTransportReady||widget.onSendMessage==null)){
      _showError('Verified encryption is required for voice messages.');
      return;
    }
    final capture=await OrbitChatVoiceRecorder.open(context);
    if(capture==null||!mounted)return;
    try{
      final data=Uint8List.fromList(await capture.file.readAsBytes());
      final message=_newMine(type:DirectChatMessageType.sentAudio,
        audioUrl:capture.file.path,audioBytes:data,
        audioDuration:Duration(milliseconds:capture.durationMs));
      if(widget.liveMode){
        await widget.onSendMessage!(message);
      }else{
        await widget.onSendMessage?.call(message);
      }
      if(!mounted)return;
      setState(()=>_messages.add(message.copyWith(
        deliveryStatus:DirectChatDeliveryStatus.sent)));
      _scrollToLatest();
    }catch(_){
      if(mounted)_showError('Encrypted voice message was not confirmed.');
    }finally{
      try{if(await capture.file.exists())await capture.file.delete();}catch(_){}
    }
  }

  Future<void> _shareLocation() async {
    if(widget.liveMode){
      _showError('Chat location sharing is unavailable. Use Orbit location sharing instead.');
      return;
    }
    FocusScope.of(context).unfocus();
    final live = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF7C3AED),
                ),
                title: const Text('Share current location'),
                onTap: () => Navigator.pop(sheetContext, false),
              ),
              ListTile(
                leading: const Icon(
                  Icons.location_searching_rounded,
                  color: Color(0xFF7C3AED),
                ),
                title: const Text('Share live location'),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || live == null) return;

    final allowed = await Navigator.of(context).push<bool>(
      AppFadeSlidePageRoute<bool>(
        builder: (permissionContext) => ShareLocationScreen(
          onAllowAlways: () => Navigator.of(permissionContext).pop(true),
          onAllowWhileUsing: () => Navigator.of(permissionContext).pop(true),
          onNotNow: () => Navigator.of(permissionContext).pop(false),
        ),
      ),
    );
    if (!mounted || allowed != true) return;

    final message = _newMine(
      type: DirectChatMessageType.locationMessage,
      latitude: 25.7826,
      longitude: -80.1341,
      locationName: live ? 'Live · South Beach' : 'South Beach',
      mapImagePath: widget.mapImagePath,
    );
    setState(() => _messages.add(message));
    _scrollToLatest();
    await widget.onSendMessage?.call(message);
  }

  DirectChatMessage _newMine({
    required DirectChatMessageType type,
    String? text,
    String? imageUrl,
    String? audioUrl,
    Uint8List? audioBytes,
    Duration? audioDuration,
    List<String> images = const <String>[],
    double? latitude,
    double? longitude,
    String? locationName,
    String? mapImagePath,
    String? replyToId,
    String? videoUrl,
    Duration? videoDuration,
  }) {
    final now = DateTime.now();
    return DirectChatMessage(
      id: 'local-${now.microsecondsSinceEpoch}',
      conversationId: widget.conversationId,
      type: type,
      senderId: widget.currentUserId,
      senderName: 'You',
      isMine: true,
      text: text,
      replyToId:replyToId,
      videoUrl:videoUrl,videoDuration:videoDuration,
      imageUrl: imageUrl,
      audioUrl:audioUrl,
      audioBytes:audioBytes,
      audioDuration:audioDuration,
      images: images,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      mapImagePath: mapImagePath,
      timestamp: _formatTime(now),
      createdAt: now,
      deliveryStatus: DirectChatDeliveryStatus.sending,
      showDeliveryStatus:widget.liveMode,
    );
  }

  Future<void> _changeReaction(
    DirectChatMessage message,
    ChatReactionKind? selected,
    Map<ChatReactionKind, int> counts,
  ) async {
    if(widget.liveMode && message.id.startsWith('local-')){
      _showError('Wait for the encrypted message to finish syncing.');
      throw StateError('A local message has no server recipient ID.');
    }
    if(widget.liveMode && widget.onReactionChanged==null){
      _showError('Encrypted reactions are not yet available.');
      throw StateError('Encrypted reaction callback is unavailable.');
    }
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index < 0) return;
    final previous = _messages[index];
    final backendCounts = <String, int>{
      for (final entry in counts.entries) entry.key.backendValue: entry.value,
    };
    final updated = previous.copyWith(
      reactions: backendCounts,
      selectedReaction: selected?.backendValue,
      clearSelectedReaction: selected == null,
    );
    setState(() => _messages[index] = updated);
    try {
      await widget.onReactionChanged?.call(
        message.id,
        selected?.backendValue,
        backendCounts,
      );
    } catch (_) {
      if (mounted) setState(() => _messages[index] = previous);
      rethrow;
    }
  }

  void _openMap(DirectChatMessage? message) {
    if (widget.onViewMap != null) {
      widget.onViewMap!();
      return;
    }
    final locationName = message?.locationName ?? 'South Beach';
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => _DirectLiveLocationMapScreen(
          mapImagePath: message?.mapImagePath ?? widget.mapImagePath,
          locationName: locationName,
        ),
      ),
    );
  }

  void _showError(String text) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF9F9F9),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildHeader(context),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildScrollableBody()),
            if(widget.liveMode && !widget.encryptedTransportReady)
              const Padding(
                padding:EdgeInsets.symmetric(horizontal:20,vertical:8),
                child:Text('Messages are private. Verified encryption setup is required before sending.',
                  textAlign:TextAlign.center,
                  style:TextStyle(fontFamily:AppTypography.fontFamily,
                    fontSize:12,color:Color(0xFF64748B))),
              ),
            if(_replyTo!=null)_replyBanner(),
            SafeArea(
              top: false,
              child: DirectChatInputBar(
                personName: widget.person.name,
                controller: _messageController,
                focusNode: _messageFocusNode,
                onAttachment: _openAttachments,
                onLocation: _shareLocation,
                onSend: _sendText,
                enabled: !widget.liveMode || widget.encryptedTransportReady,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: AppCircularIconButton(
              key: DirectChatScreenKeys.backButton,
              semanticLabel: 'Back',
              size: 40,
              iconSize: 24,
              icon: Icons.chevron_left_rounded,
              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            ),
          ),
          const Text(
            'Chat',
            key: DirectChatScreenKeys.title,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          if(widget.onMorePressed!=null)
            Align(
              alignment:Alignment.centerRight,
              child:AppCircularIconButton(
                semanticLabel:'Conversation options',
                size:40,iconSize:24,icon:Icons.more_horiz_rounded,
                onPressed:widget.onMorePressed!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollableBody() {
    if (widget.viewState == DirectChatViewState.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      );
    }
    if (widget.viewState == DirectChatViewState.error) {
      return _DirectErrorState(
        message: widget.errorMessage,
        onRetry: widget.onRetry,
      );
    }

    return CustomScrollView(
      key: DirectChatScreenKeys.scroll,
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: DirectChatProfileHeader(person: widget.person),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if(!widget.liveMode) SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: KeyedSubtree(
              key: DirectChatScreenKeys.liveLocationCard,
              child: LiveLocationCard(
                mapImagePath: widget.mapImagePath,
                title: 'Sharing live location',
                subtitle: 'South Beach · 0.4 mi away',
                onViewMap: () => _openMap(null),
              ),
            ),
          ),
        ),
        if(!widget.liveMode) const SliverToBoxAdapter(child: SizedBox(height: 24)),
        if(!widget.liveMode) const SliverToBoxAdapter(
          child: Center(
            child: Text(
              'Today · 9:32 AM',
              key: DirectChatScreenKeys.dateSeparator,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B95A1),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
        if (_loadingOlder)
          const SliverToBoxAdapter(
            child: Center(
              key: DirectChatScreenKeys.loadingOlder,
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        if (_messages.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
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
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index.isOdd) return const SizedBox(height: 12);
                final message = _messages[index ~/ 2];
                return KeyedSubtree(
                  key: DirectChatScreenKeys.message(message.id),
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
                    initialSelected: _reactionFromBackend(
                      message.selectedReaction,
                    ),
                    initialCounts: _countsFromBackend(message.reactions),
                    onChanged: (id, selected, counts) =>
                        _changeReaction(message, selected, counts),
                    child:widget.liveMode &&
                      !message.isMine &&
                      message.readEnvelopeId!=null &&
                      widget.onMessageViewed!=null
                      ?OrbitMessageVisibilityObserver(
                        onDwell:()=>widget.onMessageViewed!(
                          message.readEnvelopeId!),
                        child:_buildMessage(message))
                      :_buildMessage(message),
                    ),
                  ),
                );
              }, childCount: (_messages.length * 2) - 1),
            ),
          ),
      ],
    );
  }

  Widget _buildMessage(DirectChatMessage message) {
    switch (message.type) {
      case DirectChatMessageType.receivedText:
        return DirectReceivedTextMessage(message: message);
      case DirectChatMessageType.sentText:
        return DirectSentTextMessage(message: message);
      case DirectChatMessageType.receivedAudio:
      case DirectChatMessageType.sentAudio:
        return ChatAudioMessage(
          audioSource: message.audioBytes!=null ? '' : (message.audioUrl ?? 'assets/audio/group_voice_demo.wav'),
          audioBytes:message.audioBytes,
          duration: message.audioDuration ?? const Duration(seconds: 8),
          timestamp: message.timestamp,
          isMine: message.isMine,
        );
      case DirectChatMessageType.receivedImage:
      case DirectChatMessageType.sentImage:
        return SingleImageMessage(
          source: message.imageUrl ?? '',
          bytes:message.imageBytes,
          timestamp: message.timestamp,
          isMine: message.isMine,
        );
      case DirectChatMessageType.receivedMultiImage:
      case DirectChatMessageType.sentMultiImage:
        return MultipleImageMessage(
          sources: message.images,
          timestamp: message.timestamp,
          isMine: message.isMine,
        );
      case DirectChatMessageType.locationMessage:
        return DirectLocationMessage(
          message: message,
          onOpen: () => _openMap(message),
        );
      case DirectChatMessageType.futureVideo:
      case DirectChatMessageType.futureFile:
        return _FutureDirectMessage(message: message,
          onTap:message.videoMediaId!=null && widget.onOpenVideo!=null
            ?()=>widget.onOpenVideo!(message.videoMediaId!):null);
    }
  }

  static ChatReactionKind? _reactionFromBackend(String? value) {
    if (value == null) return null;
    for (final reaction in ChatReactionKind.values) {
      if (reaction.backendValue == value) return reaction;
    }
    return null;
  }

  static Map<ChatReactionKind, int> _countsFromBackend(
    Map<String, int> values,
  ) {
    final result = <ChatReactionKind, int>{};
    for (final entry in values.entries) {
      final reaction = _reactionFromBackend(entry.key);
      if (reaction != null && entry.value > 0) result[reaction] = entry.value;
    }
    return result;
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: onTap != null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x1FA576F6),
        ),
        child: Icon(icon, color: const Color(0xFF7C3AED)),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0F1724),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _StickerChoice extends StatelessWidget {
  const _StickerChoice({required this.value, required this.icon});

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

enum _AttachmentChoice { singleImage, multipleImages, sticker, voice, video }

class _FutureDirectMessage extends StatelessWidget {
  const _FutureDirectMessage({required this.message,this.onTap});

  final DirectChatMessage message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = message.type == DirectChatMessageType.futureVideo
        ? 'Video message'
        : 'File attachment';
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap:onTap,
        borderRadius:BorderRadius.circular(16),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          onTap!=null?'▶ '+label:label,
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

class _DirectLiveLocationMapScreen extends StatelessWidget {
  const _DirectLiveLocationMapScreen({
    required this.mapImagePath,
    required this.locationName,
  });

  final String mapImagePath;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ChatMediaImage(
              source: mapImagePath,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  AppCircularIconButton(
                    semanticLabel: 'Back',
                    size: 40,
                    icon: Icons.chevron_left_rounded,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectErrorState extends StatelessWidget {
  const _DirectErrorState({required this.message, this.onRetry});

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
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final hour = time.hour == 0
      ? 12
      : (time.hour > 12 ? time.hour - 12 : time.hour);
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
