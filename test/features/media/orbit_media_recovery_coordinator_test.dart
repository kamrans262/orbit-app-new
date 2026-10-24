import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_recovery_coordinator.dart';
import 'package:orbit_ui/features/media/data/orbit_media_outbox.dart';

void main() {
  test('generic M6 recovery never consumes M7 publication drafts', () {
    OrbitQueuedMedia draft(String purpose) => OrbitQueuedMedia(
      owner:'account-a',transfer:'00000000-0000-4000-8000-000000000001',
      purpose:purpose,kind:'image',mime:'image/jpeg',variant:'original',
      fileName:'encrypted.cipher',cipherSha256:List.filled(64,'a').join(),
      cipherBytes:100,plainBytes:50,noncePrefix:'nonce',
    );
    expect(OrbitMediaRecoveryCoordinator.canGenericRetry(draft('moment')),isFalse);
    expect(OrbitMediaRecoveryCoordinator.canGenericRetry(draft('message')),isTrue);
  });

  test('does not retry when unauthenticated or outbox is empty', () async {
    var resumes = 0;
    final coordinator = OrbitMediaRecoveryCoordinator(
      currentOwner: () async => null,
      hasQueuedCiphertext: (_) async => true,
      restoreQueued: () async { resumes++; },
    );
    expect(await coordinator.tryResume(), false);
    expect(resumes, 0);
  });

  test('resumes queued encrypted media only once within cooldown', () async {
    var resumes = 0;
    final start = DateTime.utc(2026, 10, 24);
    var instant = start;
    final coordinator = OrbitMediaRecoveryCoordinator(
      currentOwner: () async => 'account-a',
      hasQueuedCiphertext: (_) async => true,
      restoreQueued: () async { resumes++; },
      now: () => instant,
    );
    expect(await coordinator.tryResume(), true);
    expect(await coordinator.tryResume(), false);
    expect(resumes, 1);
    instant = start.add(const Duration(minutes: 2));
    expect(await coordinator.tryResume(), true);
    expect(resumes, 2);
  });

  test('failed resume does not discard ciphertext and can retry later', () async {
    var attempts = 0;
    final coordinator = OrbitMediaRecoveryCoordinator(
      currentOwner: () async => 'account-a',
      hasQueuedCiphertext: (_) async => true,
      restoreQueued: () async {
        attempts++;
        if (attempts == 1) throw StateError('Disconnected');
      },
    );
    expect(await coordinator.tryResume(), false);
    expect(await coordinator.tryResume(explicitRetry: true), true);
    expect(attempts, 2);
  });
}
