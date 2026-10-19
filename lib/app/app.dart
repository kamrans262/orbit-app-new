import 'package:flutter/material.dart';

import '../features/home/presentation/screens/home_screen.dart';

import '../core/widgets/app_keyboard_dismiss.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/orbit_otp_sign_in_screen.dart';
import '../features/auth/presentation/screens/orbit_profile_basics_screen.dart';
import '../features/auth/data/orbit_identity_client.dart';
import '../features/auth/presentation/widgets/orbit_session_welcome_gate.dart';
import '../features/auth/presentation/screens/device_registration_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/presentation/screens/verify_otp_screen.dart';
import '../features/auth/presentation/screens/sign_up_screen.dart';
import '../features/welcome/presentation/screens/circle_permission_screen.dart';
import '../features/welcome/presentation/screens/create_circle_screen.dart';
import '../features/welcome/presentation/screens/invite_people_screen.dart';
import '../features/welcome/presentation/screens/notifications_screen.dart';
import '../features/welcome/presentation/screens/share_location_screen.dart';
import '../features/welcome/presentation/screens/share_moments_screen.dart';
import '../features/welcome/presentation/screens/welcome2_screen.dart';
import '../features/welcome/presentation/screens/welcome_screen.dart';
import '../features/welcome/presentation/screens/your_circle_screen.dart';
import 'routing/app_routes.dart';
import 'theme/app_theme.dart';
import '../features/app_update/presentation/orbit_update_runtime.dart';
import '../features/connectivity/presentation/orbit_connectivity_runtime.dart';

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: <NavigatorObserver>[
        OrbitUpdateNavigatorObserver.instance,
        OrbitConnectivityNavigatorObserver.instance,
      ],
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          AppKeyboardDismiss(child: child ?? const SizedBox.shrink()),
      initialRoute: AppRoutes.welcome,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.welcome:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => OrbitSessionWelcomeGate(
                welcome: WelcomeScreen(
                  onGetStarted: () => Navigator.of(context).pushNamed(AppRoutes.welcome2),
                  onLogIn: () => Navigator.of(context).pushNamed(AppRoutes.login),
                ),
              ),
            );
          case AppRoutes.otpSignIn:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => OrbitOtpSignInScreen(
                onVerified: () async {
                  final state = await OrbitIdentityClient.instance.restoreSession();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacementNamed(
                    state == OrbitRestoreState.authenticated
                        ? AppRoutes.home : AppRoutes.deviceRegistration,
                  );
                },
              ),
            );
          case AppRoutes.login:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => LoginScreen(
                onLogIn: (emailOrPhone, password) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password sign-in is awaiting client approval. Use email or SMS verification.'),
                  ));
                },
                onCodeSignIn: () {
                  Navigator.of(context).pushNamed(AppRoutes.otpSignIn);
                },
                onForgotPassword: () {
                  Navigator.of(context).pushNamed(AppRoutes.resetPassword);
                },
                onAppleLogin: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Apple sign-in will be enabled after provider verification is configured.'),
                  ));
                },
                onGoogleLogin: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Google sign-in will be enabled after provider verification is configured.'),
                  ));
                },
                onSignUp: () {
                  Navigator.of(context).pushNamed(AppRoutes.signUp);
                },
              ),
            );
          case AppRoutes.deviceRegistration:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => DeviceRegistrationScreen(
                onBack: () => Navigator.of(context).maybePop(),
                onContinue: () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.profileBasics);
                },
                onRegisterDevice: OrbitIdentityClient.instance.registerDevice,
              ),
            );
          case AppRoutes.profileBasics:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => OrbitProfileBasicsScreen(
                onCompleted: () => Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.notifications),
              ),
            );
          case AppRoutes.signUp:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => SignUpScreen(
                onSignUp: (_, _, _) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Use verified email or SMS sign-up. Password registration is awaiting client confirmation.'),
                  ));
                },
                onCodeSignUp: () {
                  Navigator.of(context).pushNamed(AppRoutes.otpSignIn);
                },
                onAppleSignUp: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Apple sign-up is awaiting provider configuration.'),
                  ));
                },
                onGoogleSignUp: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Google sign-up is awaiting provider configuration.'),
                  ));
                },
                onLogIn: () {
                  Navigator.of(context).pop();
                },
              ),
            );
          case AppRoutes.verifyOtp:
            final otpArgument = settings.arguments;
            final otpRecipient =
                otpArgument is String && otpArgument.trim().isNotEmpty
                ? otpArgument
                : '+123 45886 576';
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => VerifyOtpScreen(
                recipient: otpRecipient,
                onVerifyCode: (_) {},
              ),
            );
          case AppRoutes.resetPassword:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => ResetPasswordScreen(
                onSendResetLink: (recipient) {
                  Navigator.of(context).pushNamed(
                    AppRoutes.verifyOtp,
                    arguments: recipient.trim().isEmpty
                        ? '+123 45886 576'
                        : recipient,
                  );
                },
              ),
            );
          case AppRoutes.welcome2:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => Welcome2Screen(
                onNext: () {
                  Navigator.of(context).pushNamed(AppRoutes.shareMoments);
                },
              ),
            );
          case AppRoutes.shareMoments:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => ShareMomentsScreen(
                onNext: () {
                  Navigator.of(context).pushNamed(AppRoutes.yourCircle);
                },
              ),
            );
          case AppRoutes.yourCircle:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => YourCircleScreen(
                onNext: () {
                  Navigator.of(context).pushNamed(AppRoutes.notifications);
                },
              ),
            );
          case AppRoutes.notifications:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => NotificationsScreen(
                onAllowNotification: () {
                  Navigator.of(context).pushNamed(AppRoutes.shareLocation);
                },
                onNotNow: () {
                  Navigator.of(context).pushNamed(AppRoutes.shareLocation);
                },
              ),
            );
          case AppRoutes.shareLocation:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => ShareLocationScreen(
                onAllowAlways: () {
                  Navigator.of(context).pushNamed(AppRoutes.createCircle);
                },
                onAllowWhileUsing: () {
                  Navigator.of(context).pushNamed(AppRoutes.createCircle);
                },
                onNotNow: () {
                  Navigator.of(context).pushNamed(AppRoutes.createCircle);
                },
              ),
            );
          case AppRoutes.createCircle:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => CreateCircleScreen(
                onNext: () {
                  Navigator.of(context).pushNamed(AppRoutes.circlePermission);
                },
              ),
            );
          case AppRoutes.circlePermission:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => CirclePermissionScreen(
                onBack: () => Navigator.of(context).pop(),
                onCreateCircle: () {
                  Navigator.of(context).pushNamed(AppRoutes.invitePeople);
                },
              ),
            );
          case AppRoutes.invitePeople:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => InvitePeopleScreen(
                onInviteByContacts: () {},
                onInviteByQrCode: () {},
                onInviteByLink: () {},
                onInviteByUsername: () {},
                onAddPerson: (_) {},
                onOpenLogin: () {
                  Navigator.of(context).pushNamed(AppRoutes.login);
                },
              ),
            );
          case AppRoutes.home:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => OrbitProtectedHome(
                home: HomeScreen.demo(
                  onTabSelected: (index) {},
                  onAddPressed: () {},
                ),
              ),
            );
          default:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => WelcomeScreen(
                onGetStarted: () {
                  Navigator.of(context).pushNamed(AppRoutes.welcome2);
                },
                onLogIn: () {
                  Navigator.of(context).pushNamed(AppRoutes.login);
                },
              ),
            );
        }
      },
    );
  }
}
