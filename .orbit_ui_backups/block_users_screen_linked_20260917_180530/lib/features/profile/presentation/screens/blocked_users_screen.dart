import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';

abstract final class BlockedUsersKeys {
  static const scrollView = Key('blocked_users_scroll_view');
  static const backButton = Key('blocked_users_back_button');
  static const title = Key('blocked_users_title');
}

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({
    this.blockedUsers = const <String>[],
    this.onBack,
    super.key,
  });

  final List<String> blockedUsers;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AppScreenHeader(
                title: 'Blocked Users',
                onBack: onBack,
                backButtonKey: BlockedUsersKeys.backButton,
                titleKey: BlockedUsersKeys.title,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                key: BlockedUsersKeys.scrollView,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: blockedUsers.isEmpty ? 1 : blockedUsers.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (blockedUsers.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.person_off_outlined,
                            size: 28,
                            color: Color(0xFF7C3AED),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No blocked users',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F1724),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'People you block will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    constraints: const BoxConstraints(minHeight: 68),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      blockedUsers[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F1724),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
