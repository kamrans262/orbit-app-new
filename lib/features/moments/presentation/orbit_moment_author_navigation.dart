import 'package:flutter/material.dart';
import '../../../core/navigation/app_fade_slide_page_route.dart';
import '../../friends/data/orbit_social_repository.dart';
import '../../friends/presentation/screens/orbit_person_screen.dart';
import '../../profile/presentation/navigation/profile_navigation.dart';
import '../data/orbit_moment_repository.dart';

/// Reuse the authenticated profile screens; a Moment is not a profile grant.
Future<void> openMomentAuthor(BuildContext context,OrbitMomentRepository repository,
    OrbitLiveMoment moment,{VoidCallback? onAddPressed})async{
  try{
    final owner=await repository.currentUserId();
    if(owner==null||!await repository.remainsAuthorized(moment))throw StateError('Moment unavailable');
    if(!context.mounted)return;
    if(owner==moment.creatorId){
      await openProfileScreen(context:context,onAddPressed:onAddPressed??(){});
      return;
    }
    final social=OrbitSocialRepository();
    final person=await social.preview(moment.creatorId);
    if(!context.mounted||await repository.currentUserId()!=owner)return;
    if(!context.mounted)return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitPersonScreen(person:person,repository:social)));
  }catch(_){
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content:Text('This profile is unavailable or access has changed.')));
  }
}
