# Orbit M7 Stage 3 — Flutter implementation and UI invariants

**Flutter branch:** `feature/m7-moments-flutter` (based exclusively on verified M6 media branch). **Backend branch:** `feature/m7-moments-backend-admin`. No main merge and no Hostinger deployment.

## Reused approved app components

- `MomentsScreen`, `MomentImageCard`, `MomentStoryAvatar`, `MomentMediaImage`, original camera `MomentCameraScreen`, and `MomentPublishSheet`.
- Orbit `AppColors`, `AppTypography`, `AppScreenHeader`, `AppCircularIconButton`, `AppPrimaryButton` and existing 28/30px sheet shape.
- Restored the existing approved gradient snackbar renderer from the M2–M5 consolidated branch; no alternative colors or bespoke notification components.
- Existing camera-permission popup reused without modification.

## Actual M7 backend integration

- `OrbitMomentRepository`: authenticated M7 feed, rail, audience/privacy enumeration, friend/Circle recipient-key discovery, client-encrypted caption and comments, trusted-device photo decryption, views, reactions, reports, deletion.
- Photo publish: M6 uploads encrypted original+thumbnail, verifies readiness, creates owner OnlyMe key grant, fetches recipient keys under server-authorized M5 consent, creates envelope-backed audience grants, then commits M7 moment and requires nonempty real server UUID plus audience_keys_confirmed.
- Home Moments tab uses `OrbitLiveMomentsScreen`, not `MomentsScreen.demo`; signed-in users see only authorized server-returned Moments and private decrypted thumbnail images, with no invented popularity totals or ad cards.
- Pressing a Moment opens `OrbitLiveMomentViewer` using current authorizations, actual original ciphertext and protected comments/reactions/reports.
- Real audience picker uses Only Me, All Friends, Selected Friends and Selected Circles only as permitted by M3 global privacy, with live Circles/friends. Fail-closed for missing or revoked encryption recipients.
- Global Add action uses `OrbitMomentCameraLauncher.openLive`; M6-only private-save fallback if M7 is disabled/unavailable.

## Honesty / deferred release gates

- **Video/voice capture and video playback UI** are not completed by this photo-first integration. M6 encrypted video transport exists but live native recording/playback requires Android/iOS acceptance. Do not mark them done.
- **Offline Moment publish-outbox transaction** is not yet atomic with M6 encrypted outbox; interrupted private ciphertext is retained but a publish failure may require a new client attempt. Do not represent backend publish success without real receipt.
- Comment text is end-to-end encrypted using the already wrapped M6 original media key, a fresh AEAD nonce, and moment-specific authenticated context.
- Admin never receives the content key. Circle membership / blocking / M3 privacy / consent must be rechecked on every backend read.
- Full 74-case M7 acceptance, Apple/Android device QA, Hostinger private storage and final production release belong to Stage 4.

- Preserve the separately confirmed M6 **Save privately without publishing** option on the existing review sheet even when M7 publishing is connected. Both actions use existing Orbit buttons and status components.
