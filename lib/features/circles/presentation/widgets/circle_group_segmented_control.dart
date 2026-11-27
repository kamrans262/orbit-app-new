import 'package:flutter/material.dart';

import '../../../../core/widgets/app_two_option_segmented_control.dart';
import '../../domain/models/friend_details_models.dart';

abstract final class CircleGroupSegmentedControlKeys {
  static const circle = Key('friend_details_segment_circle');
  static const group = Key('friend_details_segment_group');
}

class CircleGroupSegmentedControl extends StatelessWidget {
  const CircleGroupSegmentedControl({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final FriendDetailsSegment value;
  final ValueChanged<FriendDetailsSegment> onChanged;

  @override
  Widget build(BuildContext context)=>AppTwoOptionSegmentedControl(
    firstLabel:'Circle',secondLabel:'Group',
    firstSelected:value==FriendDetailsSegment.circle,
    firstKey:CircleGroupSegmentedControlKeys.circle,
    secondKey:CircleGroupSegmentedControlKeys.group,
    onChanged:(first)=>onChanged(first?FriendDetailsSegment.circle:FriendDetailsSegment.group),
  );
}
