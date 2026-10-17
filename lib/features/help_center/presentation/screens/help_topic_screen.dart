import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HelpTopicScreen(
      title: 'Contact support',
      message: 'Support contact options can be connected to the Orbit support service or backend here.',
    );
  }
}

class PrivacyHelpScreen extends StatelessWidget {
  const PrivacyHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HelpTopicScreen(
      title: 'Privacy help',
      message: 'Privacy guidance and account-specific privacy help can be loaded from the backend here.',
    );
  }
}

class SafetyHelpScreen extends StatelessWidget {
  const SafetyHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HelpTopicScreen(
      title: 'Safety help',
      message: 'Safety guidance, reporting information, and emergency help resources can be connected here.',
    );
  }
}

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HelpTopicScreen(
      title: 'FAQ’s',
      message: 'Frequently asked questions and answers can be loaded dynamically from the Help Center backend.',
    );
  }
}

class HelpTopicScreen extends StatelessWidget {
  const HelpTopicScreen({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppScreenHeader(title: title),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
