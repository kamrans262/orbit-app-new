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

## Not implemented / not certified in Stage 3 yet
- Hostinger shared-hosting private chunk API and storage adapter are not yet
  coded in Laravel. Current Stage 2 backend transport is private S3/R2 only;
  no Cloudflare account is configured, so live transfers are disabled.
- Full video compression/transcoding, voice encoding and actual in-camera
  video recording need native-device codec verification.
- Real Circle recipient public-key lookup and M7 Moment publish/consent
  consumer are not present; publishing cannot be enabled without them.
- iOS/Android real-device tests, large-media/offline networking replay,
  storage-provider E2E and 56 milestone acceptance tests remain unverified.
- Existing Moments widget CI checks report layout/control failures with the
  M5 screens; no new visual design or workaround has been introduced.
- Do not merge/deploy or activate Firebase until explicit release approval.

## Design consistency rule
No new snackbars, disappearing alerts, popups, dialogs, card styles, typography,
colors, transitions or button patterns were introduced. UI behavior is routed
through the EXISTING MomentCameraScreen, MomentPublishSheet and Orbit popups.
