import '../../auth/data/orbit_identity_client.dart';
import 'orbit_media_outbox.dart';
import 'orbit_moment_media_stager.dart';
import '../../moments/data/orbit_moment_repository.dart';
import '../../moments/data/orbit_m7_rollout.dart';

/// Retries only ciphertext that the user explicitly queued earlier.
///
/// Invoked by Orbit's existing connectivity monitor after a verified online
/// probe and on resume. No new popup, snackbar, background isolate, Firebase
/// dependency, or automatic publication is introduced. Authentication and
/// current-account ownership are checked again before every retry.
class OrbitMediaRecoveryCoordinator {
  OrbitMediaRecoveryCoordinator({
    Future<String?> Function()? currentOwner,
    Future<bool> Function(String owner)? hasQueuedCiphertext,
    Future<void> Function()? restoreQueued,
    DateTime Function()? now,
    this.cooldown = const Duration(minutes: 1),
  }) : _owner = currentOwner ??
           OrbitIdentityClient.instance.currentLocalSocialOwner,
       _hasQueued = hasQueuedCiphertext ??
           ((owner) async {
         if((await OrbitMediaOutbox().pending(owner)).isNotEmpty)return true;
         // An uploaded-but-unconfirmed Moment can still have an independent
         // secure publication intent after its media transfer is finalized.
         return OrbitM7Rollout.enabled &&
           await OrbitMomentRepository().pendingPublishCount()>0;
       }),
       _restore = restoreQueued ?? _resumeSafely,
       _clock = now ?? DateTime.now;

  /// M7 requires a separate publication receipt. The generic upload retry
  /// must never consume Moment ciphertext, even when its intent is missing.
  static bool canGenericRetry(OrbitQueuedMedia entry) => entry.purpose != 'moment';

  static Future<void> _resumeSafely() async {
    // M7 moments carry a separate account-bound publication intent. The
    // generic M6 retry would discard ciphertext after uploading it, even if
    // the M7 POST never ran. Recover receipt/publish FIRST; do not let the
    // generic retry consume a Moment or an orphan Moment ciphertext draft.
    if(OrbitM7Rollout.enabled){
      await OrbitMomentRepository().resumePendingPublishes();
    }
    await OrbitMomentMediaStager().retryPending(
      shouldRetry: canGenericRetry,
    );
  }

  static final OrbitMediaRecoveryCoordinator instance =
      OrbitMediaRecoveryCoordinator();

  final Future<String?> Function() _owner;
  final Future<bool> Function(String owner) _hasQueued;
  final Future<void> Function() _restore;
  final DateTime Function() _clock;
  final Duration cooldown;
  bool _running = false;
  DateTime? _lastAttempt;

  /// Returns true only if this invocation successfully retried queued media.
  /// A failure never discards ciphertext or reports delivery to an audience.
  Future<bool> tryResume({bool explicitRetry = false}) async {
    if (_running) return false;
    final now = _clock();
    if (!explicitRetry && _lastAttempt != null &&
        now.difference(_lastAttempt!) < cooldown) return false;
    _running = true;
    try {
      final owner = await _owner();
      if (owner == null || owner.isEmpty || !await _hasQueued(owner)) {
        return false;
      }
      _lastAttempt = now;
      await _restore();
      return true;
    } catch (_) {
      // The outbox retains encrypted drafts for a later online/resume attempt.
      return false;
    } finally {
      _running = false;
    }
  }
}
