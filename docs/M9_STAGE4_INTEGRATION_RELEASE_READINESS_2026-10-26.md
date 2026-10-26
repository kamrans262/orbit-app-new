# Orbit M9 — Stage 4 Integration and Release-Readiness Audit
Date: 2026-10-26

**Status:** Source integration and focused test validation underway; production acceptance is **RELEASE BLOCKED**.
**Flutter branch:** feature/m9-presence-flutter (M8 consolidated merged in, most recently at ce55d420).
**Backend branch:** feature/m9-presence-backend-admin (M8 release baseline merged in).
**The existing consolidated branches have NOT been modified by the M9 chat.**

## Reviewed integrations
- M8 Home's verified dashboard API, safe-name cache and UI preserved. The M9 auth cleanup hooks were explicitly combined with M8 storage cleanup, not overwritten.
- M9 Presence uses M2 trusted-session HTTP and M3 global Ghost / M5 explicit Circle permission. M9 tracks only current, server-authorized active/idle snapshots; 90-second server lease, 30-second bounded display freshness, no inferred historical last-seen.
- M5 Circle Detail shows only authorized Presence. The M9 Home integration displays status only through accepted, currently authorized Circle snapshots. M8's 'Friend' label remains when there is no valid sharing. M9 never changes the M8 endpoint's own null presence value or treats friend relationship as consent.
- In-memory Home/Circle watchers are independently reference counted. Logout, identity switch, blocked/removed Circle, app background, expired data and connection loss clear/expire protected UI.
- Presence settings reuse Orbit approved header, Save, popup and toggles; users opt into a Circle for 24 hours or indefinitely (explicit choice). Global Ghost still vetoes.
- Redis WebSocket transport is opt-in; no guessed endpoint, no plaintext typing, no new colors or native popups.

## Verified CI / source evidence
- Backend test and M8 regression CI run: https://github.com/kamrans262/orbit-backend-new/actions/runs/40356973482 (PASS; 17 tests / 110 assertions, syntax, release gate correctly BLOCKED).
- Initial reconciled Flutter run: https://github.com/kamrans262/orbit-app-new/actions/runs/40356371847 (PASS).
- Dedicated Flutter M9 contract/privacy tests, M5 Circle and M8 Home regression workflow: .github/workflows/orbit-m9-presence-flutter.yml; verify latest run for final commit before promotion.
- Formal release gate and 20 scenario inventory: backend scripts/m9_release_gate.py and docs/M9_STAGE4_ACCEPTANCE_EVIDENCE.json. Passing CI does not upgrade production approval.

## Outstanding acceptance gates
1. Managed Redis/Valkey + authenticated, continuously running TLS WebSocket gateway are unprovisioned/unverified on Hostinger shared hosting. Laravel realtime publishing/ticket/introspection and Flutter socket client alone are NOT a functioning gateway. The agreed transport frame protocol remains unverified end-to-end.
2. Verify gateway per-event privacy reauthorization, no queued unauthorized replay, immediate invalidation on Ghost, blocks, consent expiry and Circle member changes, and producer coalescing with real Redis.
3. Native Android/iOS compiled builds and real phones: resume, background, force quit, airplane mode, multi-device aggregation, extreme text scaling and session recovery.
4. p95 delivery latency, battery, socket limits, rollback rehearsal and security/product approvals.
5. Standalone API/Realtime spec not available; review exact 'Recently active' and global Ghost marker UX before any live rollout. Do not fabricate last-seen history.
6. M13 real messaging/E2EE is separate; typing transport stays gated, and no demo chat is allowed to imply live messaging.

**Stage 4 decision:** code and isolated CI may be completed, but production release must remain BLOCKED until all gates have evidence. Leave Hostinger untouched and all runtime switches OFF by default.
