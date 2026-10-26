# Orbit M9 — Stage 3 Flutter Presence integration handoff
**Date:** 2026-10-26
**Branch:** `feature/m9-presence-flutter`. Independent of active M8 Flutter Home branch.
**Server contract:** `kamrans262/orbit-backend-new` `feature/m9-presence-backend-admin`.

## Integrated code
- `lib/features/presence/data/orbit_presence_rollout.dart`: compile-time switch OFF by default; optional WSS URL only when valid `wss://`; never hardcodes client keys.
- `orbit_presence_repository.dart`: authenticated M2 trusted-device API client via existing `OrbitIdentityClient.socialRequest`. Circle-scoped snapshots, self consent, heartbeat, disconnect, typing and short-lived socket ticket. No persistent cache.
- `orbit_presence_models.dart`: strongly validated server state; active-now/idle only while time-limited lease is fresh and authenticated response age is under 30 seconds. Hidden, expired or denied = UNKNOWN, never fabricated offline or last-seen history.
- `orbit_presence_socket.dart`: optional WSS adapter, 60s ticket rotated/reconnected at 45s, protected event parsing, fail closed when gateway unavailable. No URL configured by default.
- `orbit_presence_runtime.dart`: single in-memory lifecycle-aware coordinator. Runs only after verified Home authentication. Foreground heartbeat every 40 seconds, best-effort background disconnect, no background process guarantee, Circle invalidation, safe result epochs and expiry, immediate logout/account switch cleanup.
- `orbit_circle_presence_settings_screen.dart`: exact existing Orbit header/buttons/confirmation/toggle controls; manual save with explicit per-Circle 24-hour or persistent opt-in; never changes global Ghost/privacy or activates SOS/location/M13 chat.
- `orbit_live_circle_detail_screen.dart`: active-now/idle labels only for server-authorized active Circle members, role labels otherwise; privacy access entry for currently accessible Circle. No different colors or native popup design.
- `OrbitProtectedHome`: starts runtime only on authenticated screen; identity cleanup stops it.
- Focused tests in `test/features/presence`, M5 Circle UI regression tests and the M9 workflow.

## Build / deployment flags
- Default binary: M9 is OFF. Enable Flutter for an authorized isolated test build with `--dart-define=ORBIT_M9_PRESENCE_ENABLED=true`.
- `--dart-define=ORBIT_M9_WSS_URL=wss://<approved-gateway>` enables the optional socket only when a real managed TLS gateway exists. **DO NOT deploy a guessed URL or ship any gateway secrets in the app.**
- Backend M9, M5 consumer and realtime flags must separately be enabled in an approved test environment; current Hostinger shared hosting has no verified Redis + WSS gateway.
- Gateway application must accept a frame `{"type":"auth","ticket":"..."}`, send `{"type":"authenticated"}`, and forward `{"event":{type,circle_id,...}}` only after backend per-event introspection. This Flutter frame protocol remains **proposed** until a matching gateway application is deployed/tested; no live end-to-end websocket delivery is claimed.

## Privacy/security and integration boundaries
- M8 Home has `presence:null` unless separately integrated after both branches are reviewed. M8 Flutter branch was intentionally not modified.
- M3 global Ghost and M5 Circle consent/role/block/expiry always outrank Flutter state. Friends outside a qualifying Circle do not obtain Presence.
- A member losing access, user signing out, OS background, offline state or Socket failure immediately invalidates ephemeral UI data. Stale network replies cannot re-populate a cleared Circle.
- M13 chat/typing UI is a different milestone; M9 backend typing is separately disabled until authorized message grants. This Flutter client has typed calls but will not simulate typing within demo chats.
- No permanent last-seen feed because M9 backend stores only 90-second ephemeral leases. M10 location activity labels must not be fabricated.

## Stage 4 acceptance gates
- Native Android/iOS compilation and physical-device lifecycle tests.
- Actual Redis/WSS gateway deployment, event routing, forced access revocation and per-event authorization tests.
- Multi-device online/idle, 90s expiry, explicit 24h consent expiry, Ghost/block/role/removed Circle, background/OS kill/reconnect tests.
- p95 delivery latency/battery acceptance using real transport; not established by isolated widget/unit tests.
- Cross-branch M8 Home merge review and product decisions for Recently Active/Ghost badge.
- No production config changes, deployment or branch merging in Stage 3.
