import '../../auth/data/orbit_identity_client.dart';
import '../../../app/routing/app_routes.dart';

/// The only decision made before the custom splash reveals MaterialApp.
/// This route choice is not proof of access by itself: only the server-verified
/// authenticated state may create an initially trusted Home route.
class OrbitStartupResolution {
  const OrbitStartupResolution(this.route, {this.authenticated = false});
  final String route;
  final bool authenticated;
}

class OrbitStartupResolver {
  const OrbitStartupResolver(this.identity);
  final OrbitIdentityClient identity;

  Future<OrbitStartupResolution> resolve() async {
    bool returning;
    try {
      returning = await identity.hasLaunchedBefore();
      await identity.markLaunched();
    } catch (_) {
      // Secure-storage errors are not evidence that this is a new install.
      returning = true;
    }

    final state = await identity.restoreSession();
    switch (state) {
      case OrbitRestoreState.authenticated:
        try {
          await identity.preloadStartupData();
          return const OrbitStartupResolution(AppRoutes.home,
              authenticated: true);
        } on OrbitIdentityException catch (error) {
          if (error.statusCode == 403) {
            return const OrbitStartupResolution(AppRoutes.deviceRegistration);
          }
          if (error.statusCode == 409) {
            return const OrbitStartupResolution(AppRoutes.deletionStatus);
          }
          if (error.statusCode == 401) {
            return const OrbitStartupResolution(AppRoutes.login);
          }
          // Optional profile/settings failures do not invalidate /me.
          return const OrbitStartupResolution(AppRoutes.home,
              authenticated: true);
        } catch (_) {
          return const OrbitStartupResolution(AppRoutes.home,
              authenticated: true);
        }
      case OrbitRestoreState.deviceRegistration:
        return const OrbitStartupResolution(AppRoutes.deviceRegistration);
      case OrbitRestoreState.deletionPending:
        return const OrbitStartupResolution(AppRoutes.deletionStatus);
      case OrbitRestoreState.offlineProfile:
        return const OrbitStartupResolution(AppRoutes.offlineProfile);
      case OrbitRestoreState.signedOut:
        return OrbitStartupResolution(
          returning ? AppRoutes.login : AppRoutes.welcome);
    }
  }
}
