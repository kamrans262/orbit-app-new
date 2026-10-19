import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../widgets/auth_account_switch.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_divider.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_password_visibility_button.dart';
import '../widgets/auth_screen_layout.dart';
import '../widgets/auth_social_buttons.dart';

abstract final class SignUpKeys {
  static const card = Key('sign_up_card');
  static const heading = Key('sign_up_heading');
  static const subtitle = Key('sign_up_subtitle');
  static const fullNameField = Key('sign_up_full_name_field');
  static const emailField = Key('sign_up_email_field');
  static const passwordField = Key('sign_up_password_field');
  static const passwordVisibility = Key('sign_up_password_visibility');
  static const signUpButton = Key('sign_up_button');
  static const appleButton = Key('sign_up_apple_button');
  static const googleButton = Key('sign_up_google_button');
  static const logIn = Key('sign_up_log_in');
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    required this.onSignUp,
    this.preflight,
    required this.onAppleSignUp,
    required this.onGoogleSignUp,
    required this.onLogIn,
    super.key,
  });

  final void Function(String fullName, String emailOrPhone, String password)
  onSignUp;
  // Validate the new identity and request its OTP before leaving Sign Up.
  final Future<String?> Function(String fullName, String emailOrPhone, String password)? preflight;
  final VoidCallback onAppleSignUp;
  final VoidCallback onGoogleSignUp;
  final VoidCallback onLogIn;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _fullNameController.text;
    final destination = _emailController.text;
    final password = _passwordController.text;
    if (widget.preflight == null) {
      widget.onSignUp(name, destination, password);
      return;
    }
    setState(() => _submitting = true);
    String? error;
    try {
      error = await widget.preflight!(name, destination, password);
    } catch (_) {
      error = 'Unable to connect to Orbit. Please try again.';
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    widget.onSignUp(name, destination, password);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      child: AuthCard(
        cardKey: SignUpKeys.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AuthHeader(
              heading: 'Create your account 👋',
              subtitle: 'Sign up to get started',
              headingKey: SignUpKeys.heading,
              subtitleKey: SignUpKeys.subtitle,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Full Name',
              fieldKey: SignUpKeys.fullNameField,
              controller: _fullNameController,
              hintText: 'Emma Johnson',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email or Phone',
              fieldKey: SignUpKeys.emailField,
              controller: _emailController,
              hintText: 'example@email.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Password',
              fieldKey: SignUpKeys.passwordField,
              controller: _passwordController,
              hintText: '••••••••',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              suffixIcon: AuthPasswordVisibilityButton(
                buttonKey: SignUpKeys.passwordVisibility,
                obscurePassword: _obscurePassword,
                color: const Color(0xFF7C3AED),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              key: SignUpKeys.signUpButton,
              child: AppPrimaryButton(label: 'Sign Up', onPressed: _submit, enabled: !_submitting),
            ),
            const SizedBox(height: 20),
            const AuthDivider(),
            const SizedBox(height: 16),
            AuthSocialButtons(
              appleKey: SignUpKeys.appleButton,
              googleKey: SignUpKeys.googleButton,
              onApplePressed: widget.onAppleSignUp,
              onGooglePressed: widget.onGoogleSignUp,
            ),
            const SizedBox(height: 16),
            AuthAccountSwitch(
              prompt: 'Already have an account?',
              actionLabel: 'Log In',
              actionKey: SignUpKeys.logIn,
              onActionPressed: widget.onLogIn,
            ),
          ],
        ),
      ),
    );
  }
}
