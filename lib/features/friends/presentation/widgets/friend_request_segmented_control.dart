import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

abstract final class FriendRequestSegmentedControlKeys {
  static const received = Key('friend_requests_segment_received');
  static const sent = Key('friend_requests_segment_sent');
  static const indicator = Key('friend_requests_selected_indicator');
}

/// Shares the approved Orbit Circle Invite pill-selection design, including
/// its dimensions, gradient, shadow and animated position.
class FriendRequestSegmentedControl extends StatelessWidget {
  const FriendRequestSegmentedControl({
    required this.value,
    required this.onChanged,
    super.key,
  }) : assert(value == 'incoming' || value == 'outgoing');

  static const double height = 56;
  static const double radius = 30;
  static const Duration animationDuration = Duration(milliseconds: 260);
  static const List<String> directions = <String>['incoming', 'outgoing'];

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = value == 'incoming' ? 0 : 1;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / directions.length;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F1F6),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AnimatedPositioned(
                  key: FriendRequestSegmentedControlKeys.indicator,
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  left: segmentWidth * selectedIndex + 4,
                  top: 4,
                  bottom: 4,
                  width: segmentWidth - 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFFC857D6),
                          Color(0xFF7C5CFC),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x16000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: directions.map((direction) {
                    final selected = direction == value;
                    final label = direction == 'incoming' ? 'Received' : 'Sent';
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: '$label friend requests',
                        child: GestureDetector(
                          key: direction == 'incoming'
                              ? FriendRequestSegmentedControlKeys.received
                              : FriendRequestSegmentedControlKeys.sent,
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(direction),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: animationDuration,
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 16,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF303030),
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
