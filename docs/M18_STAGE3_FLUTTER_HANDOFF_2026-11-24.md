# ORBIT M18 Stage 3 — Flutter integration, approved UI only

**Date:** 2026-11-24
**Base Flutter:** feature/m17-moderation-flutter-2026-11-24 (2fe87f58)
**New Flutter:** feature/m18-activity-flutter-2026-11-24
**Backend:** feature/m18-activity-backend-admin-2026-11-24 (0acc1bf1)
**Deploy:** No app release, no Hostinger migration, no key changes.

## Implemented

- Strict typed, owner-checked, memory-only Activity repository using the actual Stage 2 API: capabilities, feed, changes, items.
- Stage 2 /changes reset_required=true triggers mandatory authoritative refresh; M18 cursors are never persisted.
- Existing Moments feed uses existing MomentImageFeedItem and MomentTextFeedItem UI; authorized Check-In Activity appears chronologically alongside M7 Moments using the existing styled text card.
- Every Check-In pointer is materialized via the original M12 authenticated /check-ins/{id}; action revalidates the M18 item first and opens the EXISTING Check-In detail sheet. Never use the M7 Moment report sheet for Check-Ins.
- Only whole-app Moments feed may show Check-In events: dedicated Circle/profile Moment lists remain unchanged.
- Activity state is discarded on reload, pause, session failure and logout/navigation dispose. No offline Check-In text or thumbnails stored.
- Missing/not-yet-deployed Activity API fails closed for M18 and preserves existing independent M7 source feed; no false claims of realtime or server receipt.
- No new UI screens, tabs, navigation items, colors, popups, image assets or component styles.
- Contract, owner-switch, pagination, source-allowlist and UI preservation widget tests.

## Known gates

- Stage 2 backend remains undeployed; the Activity source appears only when the backend is enabled and real projected records exist.
- Only Moments and Check-In source types are allowlisted. No Ping, Plans, SOS, messaging, location, moderation or ads may appear via this adapter.
- Stage 2 does not provide verified viewer-specific incremental tombstones/realtime; Flutter uses safe authorized full refresh. Sources remain authoritative.
- Stage 4 original PRD/TRD reconciliation, privacy and offline QA, performance, Android/iOS real device testing and release approvals remain.
