import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/orbit_searchable_header.dart';
import '../../../circles/domain/models/friend_details_models.dart';
import '../../../direct_chat/presentation/screens/direct_chat_screen.dart';
import '../../../home/presentation/widgets/home_media_image.dart';

abstract final class MessagesKeys {
  static const scroll = Key('messages_scroll');
  static const title = Key('messages_title');
  static const searchButton = Key('messages_search_button');
  static const closeSearchButton = Key('messages_close_search_button');
  static const emptyState = Key('messages_empty_state');

  static Key row(String id) => Key('messages_row_$id');
  static Key send(String id) => Key('messages_send_$id');
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({required this.friends, this.onBack,
    this.onOpenFriend, this.isLoading=false, this.statusMessage, super.key});

  factory MessagesScreen.demo({VoidCallback? onBack}) {
    return MessagesScreen(
      friends: const <FriendMemberData>[
        FriendMemberData(
          id: 'emma',
          name: 'Emma',
          status: 'Active now',
          imagePath: 'assets/Emma.png',
          isFavorite: true,
        ),
        FriendMemberData(
          id: 'mike',
          name: 'Mike',
          status: 'Active 5m ago',
          imagePath: 'assets/Mike.png',
        ),
        FriendMemberData(
          id: 'sophia',
          name: 'Sophia',
          status: 'Active 12m ago',
          imagePath: 'assets/Sophia.png',
          isFavorite: true,
        ),
      ],
      onBack: onBack,
    );
  }

  final List<FriendMemberData> friends;
  final VoidCallback? onBack;
  final ValueChanged<FriendMemberData>? onOpenFriend;
  final bool isLoading;
  final String? statusMessage;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const double _horizontalPadding = 20;
  static const double _topPadding = 20;
  static const double _headerToListGap = 20;
  static const double _rowGap = 10;

  final OrbitSearchController _searchController = OrbitSearchController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FriendMemberData> get _visibleFriends {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.friends;
    }

    return widget.friends
        .where((friend) {
          return friend.name.toLowerCase().contains(query) ||
              friend.status.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleFriends = _visibleFriends;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  _topPadding,
                  _horizontalPadding,
                  0,
                ),
                child: OrbitSearchableHeader(
                  title: 'Messages',
                  placeholder: 'Search friends',
                  controller: _searchController,
                  onQueryChanged: (value) {
                    setState(() => _query = value);
                  },
                  onBack: widget.onBack,
                  titleKey: MessagesKeys.title,
                  searchButtonKey: MessagesKeys.searchButton,
                  closeButtonKey: MessagesKeys.closeSearchButton,
                ),
              ),
              const SizedBox(height: _headerToListGap),
              Expanded(
                child: widget.isLoading
                    ? const Center(child:CircularProgressIndicator(
                        color:AppColors.primaryEnd))
                    : widget.statusMessage!=null
                      ? Center(child:Padding(
                          padding:const EdgeInsets.all(24),
                          child:Text(widget.statusMessage!,textAlign:TextAlign.center,
                            style:const TextStyle(
                              fontFamily:AppTypography.fontFamily,
                              fontSize:14,color:AppColors.textMuted)),
                        ))
                    : visibleFriends.isEmpty
                    ? const _MessagesEmptyState()
                    : ListView.separated(
                        key: MessagesKeys.scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(
                          _horizontalPadding,
                          0,
                          _horizontalPadding,
                          28,
                        ),
                        itemCount: visibleFriends.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: _rowGap),
                        itemBuilder: (context, index) {
                          final friend = visibleFriends[index];
                          return _MessageFriendTile(
                            key: MessagesKeys.row(friend.id),
                            friend: friend,
                            sendKey: MessagesKeys.send(friend.id),
                            onPressed: () => _openDirectChat(friend),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDirectChat(FriendMemberData friend) {
    if(widget.onOpenFriend!=null){
      widget.onOpenFriend!(friend);
      return;
    }
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => DirectChatScreen.demo(
          personName: friend.name,
          avatarPath: friend.imagePath,
        ),
      ),
    );
  }
}

class _MessageFriendTile extends StatelessWidget {
  const _MessageFriendTile({
    required this.friend,
    required this.sendKey,
    required this.onPressed,
    super.key,
  });

  final FriendMemberData friend;
  final Key sendKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 74),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                HomeAvatar(
                  imagePath: friend.imagePath ?? '',
                  name: friend.name,
                  size: 46,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        friend.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontFamilyFallback: <String>[
                            'Noto Color Emoji',
                            'Apple Color Emoji',
                            'Segoe UI Emoji',
                          ],
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        friend.status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontFamilyFallback: <String>[
                            'Noto Color Emoji',
                            'Apple Color Emoji',
                            'Segoe UI Emoji',
                          ],
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Message ${friend.name}',
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.primaryStart,
                          AppColors.primaryEnd,
                        ],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: sendKey,
                        onTap: onPressed,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: SizedBox.square(
                          dimension: 40,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/send.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagesEmptyState extends StatelessWidget {
  const _MessagesEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: MessagesKeys.emptyState,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No friends found',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
