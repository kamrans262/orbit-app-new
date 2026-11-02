# Orbit M14 — Stage 3 Flutter Implementation Handoff

Date: November 2, 2026.
Branch: feature/m14-notifications-flutter-2026-11-02.
Base: integration/m2-m5-flutter-consolidated-2026-10-24, commit 878ef5e.
Backend dependency: feature/m14-notifications-backend-admin-2026-11-02, commit 3fb77cf.

## Committed scope

- Owner-bound Laravel API repository for unified inbox, unread, read/read-all, push bootstrap and device registration.
- Existing Profile notification settings screen retained and wired to M3 GET/PATCH preferences using the seven approved keys. No demo settings displayed in authenticated flow.
- A unified Notifications screen reuses Orbit headers, typography, white background, list rows, gradient snackbar and Circle sheets.
- Notification taps recheck ACL against live source APIs: Moments, Pings, Check-Ins, Messages, Friends, Circles and account security. Unsupported, blocked, expired or revoked targets remain unavailable.
- Existing Home bell links to unified inbox. A compact unread badge displays only authoritative server counts; values clear on pause, logout, account change or failure.
- Existing onboarding /notifications route remains unchanged; new unified inbox is /inbox/notifications.
- Existing private M7 Moments notification screen remains available from the error state during M14 backend rollout.
- Shared push runtime checks the backend readiness response before calling Firebase. It handles token registration/rotation/unregister, foreground generic invalidations, background opens and cold-start provider events. Push remains disabled without verified Firebase and APNs readiness; no private payloads are used.
- Existing M7 Firebase and notification implementations, Admin visual redesign branch, Laravel and production hosting are untouched.

## Verification still required

- Flutter/Dart SDK is not available in this runtime. Static source/contract checks are possible; a passing flutter analyze, Flutter build, Android/iOS runtime or physical device push receipt is NOT claimed.
- Run flutter pub get, flutter analyze, flutter test test/features/notifications test/features/profile/presentation/notification_navigation_test.dart, then flutter build apk and real-device flutter run from the user's Mac.
- Backend M14 migrations and Laravel scheduled workers have NOT been deployed; Stage 4 must reconcile Hostinger live state before applying additive changes.
- Confirm account switching, token rotation, opt-out, blocking, Circle and Moment mute, push server flags, pagination, device approvals, network errors and notification tap authorization.
- Server sends generic FCM data-only events, not OS-visible alert content. Do not claim background or terminated notification tray delivery without an approved native notification display design and actual Android/iOS testing.
- No new SOS, billing, Plans, Redis/WebSocket, demo data, or unapproved design changes.
