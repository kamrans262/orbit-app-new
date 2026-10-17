import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/group_chat_models.dart';
import '../widgets/chat_input_bar.dart';
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
typedef LoadOlderMessagesCallback = FutureOr<List<GroupChatMessage>> Function();
typedef ReactionChangedCallback = FutureOr<void> Function(
  GroupChatMessage message,
  ChatReactionState reaction,
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
    this.onLoadOlder,
    this.hasMoreOlder = false,
    this.onReactionChanged,
    super.key,
  });

  factory GroupChatScreen.demo({VoidCallback? onBack}) {
    final now = DateTime.now();
    return GroupChatScreen(
      title: 'peak seekers',
      memberCount: 9,
      participants: const <GroupParticipant>[
        GroupParticipant(
          id: 'emma',
          name: 'Emma',
          avatarPath: 'assets/Emma.png',
        ),
        GroupParticipant(
          id: 'mike',
          name: 'Mike',
          avatarPath: 'assets/Mike.png',
        ),
        GroupParticipant(
          id: 'sophia',
          name: 'Sophia',
          avatarPath: 'assets/Sophia.png',
        ),
      ],
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
  final LoadOlderMessagesCallback? onLoadOlder;
  final bool hasMoreOlder;
  final ReactionChangedCallback? onReactionChanged;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  static const Color _chatBackground = Color(0xFFF0EEEB);
  static const double _messageGap = 13;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  late List<GroupChatMessage> _messages;
  bool _loadingOlder = false;
  bool _initialScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _messages = List<GroupChatMessage>.of(widget.messages);
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

  @override
  void dispose() {
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

  Future<void> _sendCurrentMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final optimisticMessage = GroupChatMessage(
      id: 'local-${now.microsecondsSinceEpoch}',
      type: GroupChatMessageType.sentText,
      senderId: widget.currentUserId,
      senderName: 'You',
      isMine: true,
      text: text,
      timestamp: _formatTime(now),
      createdAt: now,
    );

    setState(() => _messages.add(optimisticMessage));
    _messageController.clear();
    _scheduleScrollToBottom();

    try {
      await widget.onSendMessage?.call(text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message could not be sent.')),
      );
    }
  }

  Future<void> _changeReaction(
    GroupChatMessage message,
    ChatReactionState next,
  ) async {
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
            ),
            Expanded(child: _buildBody()),
            SafeArea(
              top: false,
              child: ChatInputBar(
                controller: _messageController,
                focusNode: _messageFocusNode,
                onSend: _sendCurrentMessage,
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
              child: _buildMessage(message),
            );
          },
        );
    }
  }

  Widget _buildMessage(GroupChatMessage message) {
    switch (message.type) {
      case GroupChatMessageType.receivedText:
        return ReceivedTextMessage(message: message);
      case GroupChatMessageType.sentText:
        return SentTextMessage(message: message);
      case GroupChatMessageType.sentVoice:
        return SentVoiceMessage(message: message);
      case GroupChatMessageType.receivedImage:
        return ReceivedImageMessage(
          message: message,
          onReactionChanged: (reaction) => _changeReaction(message, reaction),
        );
      case GroupChatMessageType.futureAudio:
      case GroupChatMessageType.futureVideo:
      case GroupChatMessageType.futureFile:
      case GroupChatMessageType.futureSystemMessage:
        return _FutureMessagePlaceholder(message: message);
    }
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
  const _FutureMessagePlaceholder({required this.message});

  final GroupChatMessage message;

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
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xC7FFFFFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label.isEmpty ? 'Group update' : label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
