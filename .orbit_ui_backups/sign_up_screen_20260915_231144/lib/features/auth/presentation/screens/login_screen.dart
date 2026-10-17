import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_social_button.dart';
import '../../../../core/widgets/app_text_field.dart';

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
  static const double _screenHorizontalMargin = 20;
  static const double _screenVerticalMargin = 20;
  static const double _cardRadius = 30;
  static const double _cardTopPadding = 36;
  static const double _cardHorizontalPadding = 24;
  static const double _cardBottomPadding = 28;
  static const double _maxCardWidth = 560;

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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minimumCenteredHeight = math.max(
              0.0,
              constraints.maxHeight -
                  (_screenVerticalMargin * 2) -
                  keyboardInset,
            );

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                _screenHorizontalMargin,
                _screenVerticalMargin,
                _screenHorizontalMargin,
                _screenVerticalMargin + keyboardInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumCenteredHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxCardWidth),
                    child: _LoginCard(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      obscurePassword: _obscurePassword,
                      onTogglePassword: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      onForgotPassword: widget.onForgotPassword,
                      onLogIn: _submit,
                      onAppleLogin: widget.onAppleLogin,
                      onGoogleLogin: widget.onGoogleLogin,
                      onSignUp: widget.onSignUp,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onLogIn,
    required this.onAppleLogin,
    required this.onGoogleLogin,
    required this.onSignUp,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onLogIn;
  final VoidCallback onAppleLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_LoginScreenState._cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          key: LoginKeys.card,
          padding: const EdgeInsets.fromLTRB(
            _LoginScreenState._cardHorizontalPadding,
            _LoginScreenState._cardTopPadding,
            _LoginScreenState._cardHorizontalPadding,
            _LoginScreenState._cardBottomPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_LoginScreenState._cardRadius),
            border: Border.all(width: 1, color: const Color(0x14FFFFFF)),
          ),
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
                controller: emailController,
                hintText: 'Emma Johnson',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password',
                fieldKey: LoginKeys.passwordField,
                controller: passwordController,
                hintText: '••••••••',
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                labelTrailing: _ForgotPasswordAction(
                  onPressed: onForgotPassword,
                ),
                suffixIcon: _PasswordVisibilityAction(
                  obscurePassword: obscurePassword,
                  onPressed: onTogglePassword,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                key: LoginKeys.loginButton,
                child: AppPrimaryButton(label: 'Log in', onPressed: onLogIn),
              ),
              const SizedBox(height: 20),
              const _OrContinueDivider(),
              const SizedBox(height: 16),
              _SocialButtons(
                onAppleLogin: onAppleLogin,
                onGoogleLogin: onGoogleLogin,
              ),
              const SizedBox(height: 16),
              _AccountPrompt(onSignUp: onSignUp),
            ],
          ),
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

class _PasswordVisibilityAction extends StatelessWidget {
  const _PasswordVisibilityAction({
    required this.obscurePassword,
    required this.onPressed,
  });

  final bool obscurePassword;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscurePassword ? 'Show password' : 'Hide password',
      child: InkWell(
        key: LoginKeys.passwordVisibility,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(23),
        child: SizedBox.square(
          dimension: AppTextField.referenceHeight,
          child: Icon(
            obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 19,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _OrContinueDivider extends StatelessWidget {
  const _OrContinueDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0xFFD8D8D8)),
        ),
        SizedBox(width: 12),
        Text(
          'or continue with',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0xFFD8D8D8)),
        ),
      ],
    );
  }
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons({
    required this.onAppleLogin,
    required this.onGoogleLogin,
  });

  final VoidCallback onAppleLogin;
  final VoidCallback onGoogleLogin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically = constraints.maxWidth < 260;
        final apple = AppSocialButton(
          key: LoginKeys.appleButton,
          label: 'Apple',
          icon: const Icon(Icons.apple, size: 22, color: Colors.black),
          onPressed: onAppleLogin,
        );
        final google = AppSocialButton(
          key: LoginKeys.googleButton,
          label: 'Google',
          icon: const GoogleGMark(size: 20),
          onPressed: onGoogleLogin,
        );

        if (stackVertically) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[apple, const SizedBox(height: 10), google],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: apple),
            const SizedBox(width: 12),
            Expanded(child: google),
          ],
        );
      },
    );
  }
}

class _AccountPrompt extends StatelessWidget {
  const _AccountPrompt({required this.onSignUp});

  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: <Widget>[
        const Text(
          "Don't have an account?",
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
        Semantics(
          button: true,
          label: 'Sign Up',
          child: GestureDetector(
            key: LoginKeys.signUp,
            behavior: HitTestBehavior.opaque,
            onTap: onSignUp,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Sign Up',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
