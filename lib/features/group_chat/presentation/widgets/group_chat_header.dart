import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/group_chat_models.dart';
import 'overlapping_participant_avatars.dart';

abstract final class GroupChatHeaderKeys {
  static const backButton = Key('group_chat_back_button');
  static const videoButton = Key('group_chat_video_button');
  static const title = Key('group_chat_title');
  static const onlineStatus = Key('group_chat_online_status');
  static const memberCount = Key('group_chat_member_count');
  static const participantAvatars = Key('group_chat_participant_avatars');
}

class GroupChatHeader extends StatelessWidget {
  const GroupChatHeader({
    required this.title,
    required this.participants,
    required this.memberCount,
    required this.isOnline,
    required this.onBack,
    required this.onVideoCall,
    this.onMore,
    super.key,
  });

  final String title;
  final List<GroupParticipant> participants;
  final int memberCount;
  final bool isOnline;
  final VoidCallback onBack;
  final VoidCallback onVideoCall;
  final VoidCallback? onMore;

  static const LinearGradient _gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: _gradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _HeaderCircleButton(
                        key: GroupChatHeaderKeys.backButton,
                        semanticLabel: 'Back',
                        onPressed: onBack,
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 27,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal:onMore==null?52:100),
                      child: Text(
                        title.trim().isEmpty ? 'Group chat' : title,
                        key: GroupChatHeaderKeys.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize:MainAxisSize.min,
                        children:[
                        _HeaderCircleButton(
                        key: GroupChatHeaderKeys.videoButton,
                        semanticLabel: 'Start video call',
                        onPressed: onVideoCall,
                        child: SvgPicture.asset(
                          'assets/icons/video.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        if(onMore!=null)...[
                          const SizedBox(width:8),
                          _HeaderCircleButton(
                            semanticLabel:'Circle chat options',
                            onPressed:onMore!,
                            child:const Icon(Icons.more_horiz_rounded,
                              size:24,color:Colors.white)),
                        ],
                      ],
                    ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 52,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Participant avatars stay pinned to the left while the
                    // online/member status stays pinned to the right, exactly
                    // like the Group Chat reference. Dynamic member data can
                    // never push the status block across the header.
                    const statusReserve = 112.0;
                    final avatarWidth = (constraints.maxWidth - statusReserve)
                        .clamp(72.0, 220.0);
                    final maxVisible = avatarWidth < 130 ? 2 : 3;

                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            key: GroupChatHeaderKeys.participantAvatars,
                            width: avatarWidth,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: OverlappingParticipantAvatars(
                                participants: participants,
                                memberCount: memberCount,
                                maxVisible: maxVisible,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOnline
                                          ? const Color(0xFF22C55E)
                                          : const Color(0x99FFFFFF),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isOnline ? 'Online' : 'Offline',
                                    key: GroupChatHeaderKeys.onlineStatus,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 13,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.group_outlined,
                                    size: 13,
                                    color: Color(0x99FFFFFF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$memberCount People',
                                    key: GroupChatHeaderKeys.memberCount,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 12,
                                      height: 1.25,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0x99FFFFFF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: const Color(0x1FFFFFFF),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0x2EFFFFFF), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(dimension: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}
