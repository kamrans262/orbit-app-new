import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_screen_layout.dart';

abstract final class ResetPasswordKeys {
  static const card = Key('reset_password_card');
  static const heading = Key('reset_password_heading');
  static const subtitle = Key('reset_password_subtitle');
  static const emailOrPhoneField = Key('reset_password_email_or_phone_field');
  static const sendResetLinkButton = Key(
    'reset_password_send_reset_link_button',
  );
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({required this.onSendResetLink, super.key});

  final ValueChanged<String> onSendResetLink;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _emailOrPhoneController = TextEditingController();

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSendResetLink(_emailOrPhoneController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      child: AuthCard(
        cardKey: ResetPasswordKeys.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AuthHeader(
              heading: 'Reset Your Password',
              subtitle: 'Enter Your Phone or Email',
              headingKey: ResetPasswordKeys.heading,
              subtitleKey: ResetPasswordKeys.subtitle,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Enter Email / Phone',
              fieldKey: ResetPasswordKeys.emailOrPhoneField,
              controller: _emailOrPhoneController,
              hintText: 'example@email.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 25),
            SizedBox(
              key: ResetPasswordKeys.sendResetLinkButton,
              child: AppPrimaryButton(
                label: 'Send Reset Link',
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
