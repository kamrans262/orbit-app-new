import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/splash/domain/orbit_startup_resolver.dart';

class _IdentityStub extends OrbitIdentityClient {
  _IdentityStub(this.state, {this.returning = false, this.preloadFailure});
  final OrbitRestoreState state;
  final bool returning;
  final Object? preloadFailure;
  int restorations = 0;
  int preloads = 0;
  bool marked = false;

  @override
  Future<bool> hasLaunchedBefore() async => returning;

  @override
  Future<void> markLaunched() async { marked = true; }

  @override
  Future<OrbitRestoreState> restoreSession() async {
    restorations++;
    return state;
  }

  @override
  Future<void> preloadStartupData() async {
    preloads++;
    final failure = preloadFailure;
    if (failure != null) throw failure;
  }
}

void main() {
  test('authenticated user skips Welcome, preloads, and restores once',
      () async {
    final identity = _IdentityStub(OrbitRestoreState.authenticated,
        returning: true);
    final result = await OrbitStartupResolver(identity).resolve();
    expect(result.route, AppRoutes.home);
    expect(result.authenticated, isTrue);
    expect(identity.restorations, 1);
    expect(identity.preloads, 1);
    expect(identity.marked, isTrue);
  });

  test('new install with no session opens Get Started', () async {
    final identity = _IdentityStub(OrbitRestoreState.signedOut);
    final result = await OrbitStartupResolver(identity).resolve();
    expect(result.route, AppRoutes.welcome);
    expect(result.authenticated, isFalse);
    expect(identity.preloads, 0);
  });

  test('previously used device without a valid session opens Login', () async {
    final identity = _IdentityStub(OrbitRestoreState.signedOut,
        returning: true);
    final result = await OrbitStartupResolver(identity).resolve();
    expect(result.route, AppRoutes.login);
    expect(result.authenticated, isFalse);
  });

  test('pending device trust opens verification instead of Home', () async {
    final identity = _IdentityStub(OrbitRestoreState.deviceRegistration,
        returning: true);
    final result = await OrbitStartupResolver(identity).resolve();
    expect(result.route, AppRoutes.deviceRegistration);
    expect(result.authenticated, isFalse);
  });

  test('pending deletion does not enter Home', () async {
    final identity = _IdentityStub(OrbitRestoreState.deletionPending,
        returning: true);
    final result = await OrbitStartupResolver(identity).resolve();
    expect(result.route, AppRoutes.deletionStatus);
    expect(result.authenticated, isFalse);
  });

  test('temporary network outage keeps user on offline retry path',
      () async {
    final identity = _IdentityStub(OrbitRestoreState.offlineProfile,
        returning: true);
    final result = await OrbitStartupResolver(identity).resolve();
    expect(result.route, AppRoutes.offlineProfile);
    expect(result.authenticated, isFalse);
  });

  test('expired authorization during preload never grants Home', () async {
    final identity = _IdentityStub(OrbitRestoreState.authenticated,
      returning: true,
      preloadFailure: OrbitIdentityException('Session expired', 401));
    final result = await OrbitStartupResolver(identity).resolve();
    expect(result.route, AppRoutes.login);
    expect(result.authenticated, isFalse);
  });

  test('network failure in optional preload does not undo verified login',
      () async {
    final identity = _IdentityStub(OrbitRestoreState.authenticated,
      returning: true,
      preloadFailure: OrbitIdentityException('Temporarily offline'));
    final result = await OrbitStartupResolver(identity).resolve();
    expect(result.route, AppRoutes.home);
    expect(result.authenticated, isTrue);
  });
}
