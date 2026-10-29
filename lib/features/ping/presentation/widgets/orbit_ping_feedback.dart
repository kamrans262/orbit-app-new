import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/data/orbit_identity_client.dart';

/// Approved Orbit gradient feedback. Server acceptance is never delivery.
abstract final class OrbitPingFeedback {
  static String errorText(Object error) {
    if (error is OrbitIdentityException) {
      switch(error.statusCode) {
        case 400: case 422:
          return 'Check the Ping details and try again.';
        case 401:
          return 'Sign in again to send a Ping.';
        case 403: case 404:
          return 'Recipient unavailable. Check their privacy and Circle permissions.';
        case 409:
          return 'Recipient access changed. Refresh and try again.';
        case 429:
          return 'Ping limit reached. Wait before trying again.';
        case 408: case 500: case 502: case 503: case 504:
          return 'Ping service unavailable. Retry when connected.';
      }
    }
    return 'Ping failed. Check your connection and recipient permissions.';
  }
  static void show(BuildContext context,String message,{VoidCallback? onRetry}) {
    if(!context.mounted)return;
    final messenger=ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor:Colors.transparent,elevation:0,padding:EdgeInsets.zero,
      behavior:SnackBarBehavior.floating,
      content:Container(
        decoration:BoxDecoration(gradient:AppColors.primaryGradient,
          borderRadius:BorderRadius.circular(14)),
        padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
        child:Row(children:[
          Expanded(child:Text(message,style:const TextStyle(
            color:Colors.white,fontSize:13,fontWeight:FontWeight.w500))),
          if(onRetry!=null)TextButton(onPressed:onRetry,
            style:TextButton.styleFrom(foregroundColor:Colors.white),
            child:const Text('Retry')),
        ]),
      ),
    ));
  }
}
