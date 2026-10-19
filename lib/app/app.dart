import 'package:flutter/material.dart';

import '../features/home/presentation/screens/home_screen.dart';

import '../core/widgets/app_keyboard_dismiss.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/orbit_otp_verification_controller.dart';
import '../features/auth/presentation/screens/orbit_profile_basics_screen.dart';
import '../features/auth/data/orbit_identity_client.dart';
import '../features/auth/presentation/widgets/orbit_session_welcome_gate.dart';
import '../features/auth/presentation/screens/device_registration_screen.dart';
import '../features/auth/presentation/screens/orbit_password_reset_flow.dart';
import '../features/auth/presentation/screens/orbit_account_deletion_status_screen.dart';
import '../features/auth/presentation/screens/orbit_offline_profile_screen.dart';
import '../features/auth/domain/orbit_auth_validation.dart';
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
          case AppRoutes.verifyOtp:
            final otpArgument = settings.arguments;
            if (otpArgument is OrbitOtpEntryArguments &&
                otpArgument.recipient != null) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (context) => OrbitOtpVerificationController(
                  recipient: otpArgument.recipient!,
                  password: otpArgument.password,
                  codeAlreadySent: otpArgument.codeAlreadySent,
                onVerified: () async {
                  final state = await OrbitIdentityClient.instance.restoreSession();
                  if (!context.mounted) return;
                  if (state == OrbitRestoreState.signedOut) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Unable to confirm this session. Please try logging in again.'),
                    ));
                    return;
                  }
                  final signupPending =
                      OrbitIdentityClient.instance.pendingSignupName != null;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    state == OrbitRestoreState.authenticated
                        ? (signupPending ? AppRoutes.profileBasics : AppRoutes.home)
                        : state == OrbitRestoreState.deletionPending
                            ? AppRoutes.deletionStatus : AppRoutes.deviceRegistration,
                    (_) => false,
                  );
                },
              ),
              );
            }
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
          case AppRoutes.offlineProfile:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const OrbitOfflineProfileScreen(),
            );
          case AppRoutes.deletionStatus:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => const OrbitAccountDeletionStatusScreen(),
            );
          case AppRoutes.login:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => LoginScreen(
                preflight: (emailOrPhone, password) async {
                  final error = OrbitAuthValidation.login(emailOrPhone, password);
                  if (error != null) return error;
                  try {
                    await OrbitIdentityClient.instance.requestPasswordCode(
                      emailOrPhone.trim(), password);
                    return null;
                  } on OrbitIdentityException catch (e) {
                    return e.message;
                  }
                },
                onLogIn: (emailOrPhone, password) {
                  OrbitIdentityClient.instance.abandonStandardSignup();
                  Navigator.of(context).pushNamed(
                    AppRoutes.verifyOtp,
                    arguments: OrbitOtpEntryArguments(
                      recipient: emailOrPhone.trim(),
                      password: password,
                      codeAlreadySent: true,
                    ),
                  );
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
                  // The device-registration widget invokes this callback only
                  // after the trusted key registration succeeds. An existing
                  // user returns to Home; signup completes account basics.
                  final signupPending =
                      OrbitIdentityClient.instance.pendingSignupName != null;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    signupPending ? AppRoutes.profileBasics : AppRoutes.home,
                    (_) => false,
                  );
                },
                onRegisterDevice: OrbitIdentityClient.instance.registerDevice,
                onCheckApproval: OrbitIdentityClient.instance.checkDeviceApproval,
              ),
            );
          case AppRoutes.profileBasics:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => OrbitProfileBasicsScreen(
                initialName: OrbitIdentityClient.instance.pendingSignupName,
                onCompleted: () => Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.notifications),
              ),
            );
          case AppRoutes.signUp:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => SignUpScreen(
                preflight: (fullName, emailOrPhone, password) async {
                  final destination = emailOrPhone.trim();
                  final error = OrbitAuthValidation.signup(
                      fullName, destination, password);
                  if (error != null) return error;
                  try {
                    await OrbitIdentityClient.instance.requestCode(
                      destination.contains('@') ? 'email' : 'sms',
                      destination,
                      purpose: 'signup',
                    );
                    return null;
                  } on OrbitIdentityException catch (e) {
                    return e.message;
                  }
                },
                onSignUp: (fullName, emailOrPhone, password) {
                  final destination = emailOrPhone.trim();
                  OrbitIdentityClient.instance.beginStandardSignup(fullName, password);
                  Navigator.of(context).pushNamed(
                    AppRoutes.verifyOtp,
                    arguments: OrbitOtpEntryArguments(
                      recipient: destination,
                      codeAlreadySent: true,
                    ),
                  );
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
                  OrbitIdentityClient.instance.abandonStandardSignup();
                  Navigator.of(context).pop();
                },
              ),
            );
          case AppRoutes.resetPassword:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => OrbitPasswordResetFlow(
                onCompleted: () {
                  OrbitIdentityClient.instance.abandonStandardSignup();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login, (_) => false);
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
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
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
                onSkip: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home, (_) => false,
                  );
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
                onSkip: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home, (_) => false,
                  );
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
                // Finishes this onboarding step. Sending an actual invitation
                // is owned by the separate Circles module, not this route.
                onDone: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home, (_) => false,
                  );
                },
                onSkip: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home, (_) => false,
                  );
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

/// Navigation-only parameters. Password is retained in memory only for
/// authenticated resends; it is never placed in URLs or persisted.
class OrbitOtpEntryArguments {
  const OrbitOtpEntryArguments({
    this.recipient,
    this.password,
    this.codeAlreadySent = false,
  });

  final String? recipient;
  final String? password;
  final bool codeAlreadySent;
}
