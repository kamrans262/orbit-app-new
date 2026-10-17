import 'package:flutter/material.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../screens/profile_screen.dart';

Future<int?> openProfileScreen({
  required BuildContext context,
  required VoidCallback onAddPressed,
}) {
  return Navigator.of(context).push<int>(
    AppFadeSlidePageRoute<int>(
      builder: (profileContext) => ProfileScreen.demo(
        onTabSelected: (index) {
          if (index == 3) {
            return;
          }
          Navigator.of(profileContext).pop(index);
        },
        onAddPressed: onAddPressed,
      ),
    ),
  );
}
