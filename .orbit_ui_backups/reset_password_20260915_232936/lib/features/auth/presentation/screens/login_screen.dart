import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../widgets/auth_account_switch.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_divider.dart';
import '../widgets/auth_password_visibility_button.dart';
import '../widgets/auth_screen_layout.dart';
import '../widgets/auth_social_buttons.dart';

abstract final class LoginKeys {
  static const card = Key('login_card');
  static const heading = Key('login_heading');
  static const subtitle = Key('login_subtitle');
  static const emailField = Key('login_email_field');
  static const passwordField = Key('login_password_field');
  static const forgotPassword = Key('login_forgot_password');
  static const passwordVisibility = Key('login_password_visibility');
  static const loginButton = Key('login_button');
  static const appleButton = Key('login_apple_button');
  static const googleButton = Key('login_google_button');
  static const signUp = Key('login_sign_up');
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onLogIn,
    required this.onForgotPassword,
    required this.onAppleLogin,
    required this.onGoogleLogin,
    required this.onSignUp,
    super.key,
  });

  final void Function(String emailOrPhone, String password) onLogIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onAppleLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onLogIn(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      child: AuthCard(
        cardKey: LoginKeys.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Welcome back 👋',
              key: LoginKeys.heading,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 24,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F1724),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Log in to continue',
              key: LoginKeys.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email or Phone',
              fieldKey: LoginKeys.emailField,
              controller: _emailController,
              hintText: 'Emma Johnson',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Password',
              fieldKey: LoginKeys.passwordField,
              controller: _passwordController,
              hintText: '••••••••',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              labelTrailing: _ForgotPasswordAction(
                onPressed: widget.onForgotPassword,
              ),
              suffixIcon: AuthPasswordVisibilityButton(
                buttonKey: LoginKeys.passwordVisibility,
                obscurePassword: _obscurePassword,
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              key: LoginKeys.loginButton,
              child: AppPrimaryButton(label: 'Log in', onPressed: _submit),
            ),
            const SizedBox(height: 20),
            const AuthDivider(),
            const SizedBox(height: 16),
            AuthSocialButtons(
              appleKey: LoginKeys.appleButton,
              googleKey: LoginKeys.googleButton,
              onApplePressed: widget.onAppleLogin,
              onGooglePressed: widget.onGoogleLogin,
            ),
            const SizedBox(height: 16),
            AuthAccountSwitch(
              prompt: "Don't have an account?",
              actionLabel: 'Sign Up',
              actionKey: LoginKeys.signUp,
              onActionPressed: widget.onSignUp,
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordAction extends StatelessWidget {
  const _ForgotPasswordAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Forgot Password?',
      child: GestureDetector(
        key: LoginKeys.forgotPassword,
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Text(
            'Forgot Password?',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7C3AED),
            ),
          ),
        ),
      ),
    );
  }
}
