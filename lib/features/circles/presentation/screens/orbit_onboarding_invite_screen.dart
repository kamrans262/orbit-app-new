import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../data/orbit_circle_repository.dart';
import 'orbit_live_invite_member_screen.dart';

/// A successful Circle creation stays committed even when invitations are
/// skipped. This route always exposes a clear Done action back to Home.
class OrbitOnboardingInviteScreen extends StatelessWidget {
  const OrbitOnboardingInviteScreen({
    required this.circleId, required this.onCompleted,
    super.key, this.repository,
  });

  final String circleId;
  final VoidCallback onCompleted;
  final OrbitCircleRepository? repository;

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Column(children:[
      Expanded(child:OrbitLiveInviteMemberScreen(
        circleId:circleId,repository:repository)),
      Padding(padding:const EdgeInsets.fromLTRB(20,8,20,20),
        child:SizedBox(width:double.infinity,
          child:TextButton(
            key:const Key('m5_onboarding_invites_done'),
            onPressed:onCompleted,
            child:const Text('Done — Go to Home',style:TextStyle(
              fontFamily:AppTypography.fontFamily,fontWeight:FontWeight.w600,
              color:Color(0xFF7C3AED))),
          ),
        )),
    ])),
  );
}
