import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../domain/models/check_in_models.dart';
import '../widgets/check_in_activity_selector.dart';
import '../widgets/check_in_pulse_control.dart';

abstract final class CheckInKeys {
  static const scroll = Key('check_in_scroll');
  static const close = Key('check_in_close');
  static const heart = Key('check_in_heart');
  static const activitySelector = Key('check_in_activity_selector');
}

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    required this.activities,
    this.initialActivityId,
    this.onCheckInSent,
    this.onMorePressed,
    super.key,
  });

  factory CheckInScreen.demo({
    ValueChanged<CheckInSubmission>? onCheckInSent,
    VoidCallback? onMorePressed,
  }) {
    return CheckInScreen(
      onCheckInSent: onCheckInSent,
      onMorePressed: onMorePressed,
      activities: const <CheckInActivityData>[
        CheckInActivityData(
          id: 'home',
          label: 'Home',
          iconAsset: 'assets/icons/home.svg',
          backgroundColor: Color(0xFFE4F7FF),
          iconColor: Color(0xFF35B7F1),
        ),
        CheckInActivityData(
          id: 'work',
          label: 'Work',
          iconAsset: 'assets/icons/work.svg',
          backgroundColor: Color(0xFFE9F2FF),
          iconColor: Color(0xFF5C9CF4),
        ),
        CheckInActivityData(
          id: 'driving',
          label: 'Driving',
          iconAsset: 'assets/icons/driving.svg',
          backgroundColor: Color(0xFFFFF5D8),
          iconColor: Color(0xFFF5B312),
        ),
        CheckInActivityData(
          id: 'gym',
          label: 'Gym',
          iconAsset: 'assets/icons/gym.svg',
          backgroundColor: Color(0xFFF1EAFF),
          iconColor: Color(0xFFA576F6),
        ),
        CheckInActivityData(
          id: 'travel',
          label: 'Travel',
          iconAsset: 'assets/icons/travel.svg',
          backgroundColor: Color(0xFFE4F9ED),
          iconColor: Color(0xFF2DCE78),
        ),
        CheckInActivityData(
          id: 'coffee',
          label: 'Coffee',
          iconAsset: 'assets/icons/coffee.svg',
          backgroundColor: Color(0xFFFFEDDF),
          iconColor: Color(0xFFF58A2A),
        ),
        CheckInActivityData(
          id: 'eating',
          label: 'Eating',
          iconAsset: 'assets/icons/eat.svg',
          backgroundColor: Color(0xFFFFE7E7),
          iconColor: Color(0xFFFF7272),
        ),
        CheckInActivityData(
          id: 'chill',
          label: 'Chill',
          iconAsset: 'assets/icons/chill.svg',
          backgroundColor: Color(0xFFFFE9F5),
          iconColor: Color(0xFFF06DB4),
        ),
        CheckInActivityData(
          id: 'sleep',
          label: 'Sleep',
          iconAsset: 'assets/icons/sleep.svg',
          backgroundColor: Color(0xFFEEF0FF),
          iconColor: Color(0xFF7885F3),
        ),
        CheckInActivityData(
          id: 'more',
          label: 'More',
          iconAsset: '',
          backgroundColor: Colors.black,
          iconColor: Color(0xFF94A3B8),
          isMore: true,
        ),
      ],
    );
  }

  final List<CheckInActivityData> activities;
  final String? initialActivityId;
  final ValueChanged<CheckInSubmission>? onCheckInSent;
  final VoidCallback? onMorePressed;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  static const double _horizontalPadding = 20;
  String? _selectedActivityId;

  @override
  void initState() {
    super.initState();
    _selectedActivityId = widget.initialActivityId;
  }

  CheckInActivityData? get _selectedActivity {
    for (final activity in widget.activities) {
      if (!activity.isMore && activity.id == _selectedActivityId) {
        return activity;
      }
    }
    return null;
  }

  void _send(CheckInInteractionType interactionType) {
    final activity = _selectedActivity;
    if (activity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an activity first.'),
          duration: Duration(milliseconds: 1300),
        ),
      );
      return;
    }
    widget.onCheckInSent?.call(
      CheckInSubmission(
        activityId: activity.id,
        activityName: activity.label,
        sentAt: DateTime.now(),
        interactionType: interactionType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              key: CheckInKeys.scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                _horizontalPadding,
                20,
                _horizontalPadding,
                28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildHeader(context),
                    const SizedBox(height: 50),
                    const Text(
                      'How are you?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Let your people know.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 38),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: CheckInPulseControl(
                          key: CheckInKeys.heart,
                          onTapSend: () => _send(CheckInInteractionType.tap),
                          onHoldSend: () => _send(CheckInInteractionType.hold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tap or hold to send',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE879A0),
                      ),
                    ),
                    const SizedBox(height: 35),
                    CheckInActivitySelector(
                      key: CheckInKeys.activitySelector,
                      activities: widget.activities,
                      selectedId: _selectedActivityId,
                      onSelected: (activity) {
                        setState(() => _selectedActivityId = activity.id);
                      },
                      onMorePressed: widget.onMorePressed,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Check-In',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 12),
        AppCircularIconButton(
          key: CheckInKeys.close,
          semanticLabel: 'Close Check-In',
          onPressed: () => Navigator.of(context).maybePop(),
          size: 44,
          iconSize: 24,
          icon: Icons.close_rounded,
          iconColor: const Color(0xFF94A3B8),
        ),
      ],
    );
  }
}
