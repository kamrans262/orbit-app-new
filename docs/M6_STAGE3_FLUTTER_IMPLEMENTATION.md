# Orbit M6 Stage 3 — Flutter implementation and gates

This work uses ONLY the existing repo kamrans262/orbit-app-new, branch
feature/m6-media-flutter-integration, based on the M5 Flutter branch.
The backend remains on feature/m6-media-backend-admin. No other branches
were created and no production or Firebase settings were changed.

## Implemented without introducing a new UI style
- AES-256-GCM authenticated ciphertext, random nonce-per-transfer and unique
  chunk counters, 8MiB storage-compatible chunks, X25519/HKDF device envelopes,
  account/purpose/variant authenticated data and download MAC verification.
- On-device 1440px image preprocessing, 80-quality JPEG and encrypted local
  thumbnail. Image re-encoding strips source metadata rather than uploading
  camera GPS/EXIF as-is.
- Multipart resumable ciphertext transport using the existing trusted Orbit
  identity session, short signed URL validation, part checksum/ETag enforcement,
  server verification polling and protected image download.
- OS-secured keys and application-private encrypted offline outbox, owner-bound
  resume, checksum checks, tamper rejection, and explicit file disposal.
- Photo staging service storing encrypted original+thumbnail, then grants
  only the creator's trusted device its wrapped keys. No Circle/friend sharing
  is silently enabled.
- Existing Moment camera launcher accepts an optional confirmed publisher;
  **default UI stays unchanged and preview-only**.
- MomentPublisher bridge requires actual M7 server Moment creation AND
  confirmed audience key distribution. A stored media UUID cannot be
  misrepresented as a successful Moment publication.

## M6 branch updates and still-open release gates (24 October 2026)
- Hostinger shared-hosting adapter **is implemented** in Laravel:
  authenticated private 1 MiB ciphertext chunks, outside the web root,
  alongside optional S3/R2 multipart. Real Hostinger quotas, PHP request-size
  settings, scheduler and authenticated file transfer remain unverified.
- Native p720 video transcoding, poster encryption and already encoded
  voice-clip staging exist as M6 services. Camera video-record UX and audio
  recorder/encoder belong to their approved consumer milestones until the
  actual M6 Stage 1 ownership matrix confirms otherwise. Native H.264/AAC
  profiles, bitrate, FPS and device performance remain unverified.
- Live Circle/friend public-key discovery is available in the M6 backend and
  Flutter repository. M7 Moment publish confirmation and distribution to
  recipients remain separate. Stored ciphertext is NOT a published Moment.
- Existing authenticated Orbit connectivity monitor now invokes an
  account-bound, cooldown-limited recovery coordinator for already-queued
  encrypted outbox items when connection is restored. This is foreground/
  resume recovery only: no unapproved OS background task or Firebase use.
- Camera photo temp files are explicitly cleaned up after capture. The
  preview-only publish sheet no longer injects fabricated demo Circle names.
- UI remains the current Orbit camera, review sheet, typography, colors and
  popup components; no second design system is introduced.
- Existing Moments regression test was adjusted to scroll to the actual Like
  semantics action. Current exact-head M6 CI must pass before claiming
  verification (the pre-fix run failed one regression).
- Android/iOS physical devices, real Hostinger storage, large-media/offline
  replay, and all 56 M6 acceptance cases still need evidence.
- The newer consolidated M2-M4 branch diverges from this M5-based M6 branch.
  Do not overwrite M5/M6 implementation to copy UI; reconcile after reviewing
  a complete multi-milestone diff with regression gates.
- Do not merge/deploy or activate Firebase without explicit release approval.

## Design consistency rule
No new snackbars, disappearing alerts, popups, dialogs, card styles, typography,
colors, transitions or button patterns were introduced. UI behavior is routed
through the EXISTING MomentCameraScreen, MomentPublishSheet and Orbit popups.
