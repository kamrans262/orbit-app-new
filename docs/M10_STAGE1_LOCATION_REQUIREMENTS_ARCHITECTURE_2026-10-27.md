# Orbit M10 — Stage 1 | Orbits Live Map & Location

**Recorded:** 2026-10-27  
**Flutter target:** `kamrans262/orbit-app-new`, **existing** `integration/m2-m5-flutter-consolidated-2026-10-24` at pre-audit SHA `3e7e8cd3787522994bfe47ba282698f3a93bf5fe`. No new branch.  
**Backend baseline read:** `kamrans262/orbit-backend-new`, `feature/m9-presence-backend-admin` at `e5e235d8563bef7b0e24b0ec508c219463beb07e`.  
**Status:** requirements and architecture audit only. No M10 feature code, database migrations, test runs, Hostinger deployment, or feature flag activation.

## Original sources and authority

- Master **Orbit_Complete_Organized_Specifications.pdf** from uploaded continuation pack (65 pages): PRD section 7 on p9 (PRD-050–056); PRD-023/024, PRD-033, PRD-045–047; Application Workflow section 6 on pp30–31; TRD Location/Presence on p22; Backend Schema on pp39–40; Security pp49–54; QA pp63–64.
- **Orbit development final document (1).docx**, especially §§2.5–2.7, 4.16, 6.2, 6.7, 6.8, 15.7; supplemental **Orbit_Complete backend intro in monetization.docx**.
- Latest M8/M9 current handoff and the explicit user requirement: preserve existing Orbit UI and work exclusively on the existing Flutter consolidated branch.
- The compiled master explicitly states the referenced separate **API & Realtime Specification** was not provided. Proposed endpoint and event names below are **not** confirmed client source contracts.
- “M10” is the current workstream label for **Orbits Live Map & Location**. PRD identifies the feature, not the milestone number.

## Seven mandatory PRD requirements

| ID | Original requirement |
|---|---|
| PRD-050 | Only authorized friends/Circle members actively sharing permitted location appear on map |
| PRD-051 | Permitted avatar/status/last-update/distance/battery marker metadata |
| PRD-052 | Audience: nobody, one person, selected people or selected Circles |
| PRD-053 | Precise versus approximate |
| PRD-054 | Duration: 1 hour, until tonight, until leaving, manual stop, always for trusted people |
| PRD-055 | Clearly differentiate Live, Updated X ago, Paused, Unavailable |
| PRD-056 | Never display stale location as Live |

Workflow section 6 also mandates: read-only map with permission denied, provider tiles and permitted cached markers, scope-limited realtime, marker-to-person details, review-before-activate, share-active indicator on map/profile/privacy, confirmed stop and immediate subscription revoke, and stop false live claims after OS permission revocation.

## Pinned-code findings

| Surface | Evidence | Finding |
|---|---|---|
| Flutter Orbits screen | `lib/features/orbit/presentation/screens/orbit_screen.dart` | Existing draggable sheet, markers, navigation and approved UI can be reused. Map currently renders `Image.asset('assets/orbit_map.png')` and a static `LIVE` badge; `OrbitScreen.demo` supplies sample people. This does not constitute realtime map. |
| Flutter marker model | `lib/features/orbit/domain/models/orbit_models.dart` | `markerX` / `markerY` are relative 0–1 positions, not GPS coordinates. |
| Flutter native capabilities | `pubspec.yaml`, AndroidManifest, iOS Info.plist | No dedicated real map/location SDK in audited dependencies, nor Android location permission / iOS location usage descriptions in inspected files. |
| M5 location consent | `app/Modules/Circle/Services/CircleConsentPolicy.php` | Capability and hidden/approximate/precise choices exist; preview explicitly returns `sharing_active=false` and stored settings are not an active location grant. |
| M9 Presence | `app/Modules/Presence/*`, Flutter `lib/features/presence/*` | Online/idle/Ghost state is distinct from GPS and may not be conflated. Presence settings explicitly say they do not share location. |
| M10 backend | `routes/api.php`, module tree and migrations at pinned SHA | No dedicated location ingest/share/map endpoint or location_shares/latest/history migrations. |
| Deployment | 2026-10-27 handoff + previous SSH | Redis configured connections refused; gateway and backend newer deployment not proven. No realtime/location activation should be claimed. |

## Architecture proposed for Stage 2

1. Device-authenticated, **per-viewer** map projection; use M4 friend/block and M5 Circle policy, M9 global/per-Circle Ghost precedence. Relationship/membership **never** grants location consent.
2. Explicit share review: audience, precision, duration, state. Sharing remains **OFF by default** regardless of a displayed per-Circle preference. Time-bounded grants expire server-side; no silent permanent share.
3. Separate `location_shares` grant lifecycle and a time-bounded latest-location operational store; **no automatically stored permanent GPS history**. `location_history` and `saved_places` only when separately approved.
4. On ingest: owner/trusted device, consent, timestamps, rate/accuracy/speed plausibility and idempotency. Server independently validates viewer scope on every read and live event.
5. **Server-side** approximate projection. Never send precise coordinates to a restricted viewer and cosmetically blur on Flutter.
6. Return `observed_at` and `received_at`; conservative fresh/stale/paused/unavailable classification. Do not reuse M9 online status as proof of live GPS.
7. Server-side revoke, block, leave, Ghost, trust revoke, delete, OS permissions stop immediately invalidate subscriptions/cache. Ghost grants **no last-known coordinate fallback**.
8. Use MapLibre with an approved replaceable tile provider per TRD. Adapt **existing** `OrbitScreen`/markers/sheet, shared headers/popup/snackbars and typography; do not create a new visual system or a substitute screen.
9. Location data: encrypted transit/storage where applicable, minimized retention, no precise GPS in normal logs, diagnostics, admin support views, or ad targeting.
10. Realtime requires an authenticated WSS + Redis backend or explicitly marked non-live/degraded state; **never fake LIVE with polling**.

## Suggested API/event contracts — proposals only

- `GET /api/v1/location/capabilities`
- `GET /api/v1/location/map?circle_id=...`
- `GET /api/v1/me/location/shares`
- `POST /api/v1/me/location/shares`
- `PATCH /api/v1/me/location/shares/{id}`
- `DELETE /api/v1/me/location/shares/{id}`
- `POST /api/v1/me/location/samples`
- `POST /api/v1/location/realtime/ticket`
- Scoped WSS concepts: marker updated/removed, share revoked, permissions changed; define final names/payloads before building.

No coordinate API response may be publicly cached; account changes must clear sensitive caches.

## Decisions / deviations not silently resolved

1. **Original technical baseline** Go + PostgreSQL/PostGIS; deployed source Laravel13 + MySQL on Hostinger. Maintain deployed stack; approve MySQL spatial-query/index limitations and measure performance instead of claiming PostGIS parity.
2. Full API & Realtime Spec missing: names above provisional.
3. Development Final §6.2 lists precise/persistent as settings defaults, but PRD/workflow prohibit automatic sharing: effective activation stays OFF; confirm wording/default-screen choices.
4. “Until leaving” lacks exit radius/hysteresis/geofence behavior; do not invent.
5. “Until tonight” timezone/DST interpretation unspecified.
6. Approximate precision/coarsening radius not specified. Security/product must approve.
7. “Live” age threshold and skew budget not specified. Validate with QA before badge display.
8. Vendor tile provider/keys/rate limits/fees not selected.
9. WSS, TLS Redis/Valkey, Hostinger outbound connection not currently verified.
10. Retention/paid history/visibility controls need product decisions; core M10 cannot silently implement histories.
11. Ghost mode avatar display is ambiguous; safest no-coordinates policy wins. SOS exception must use a separate future approved policy.
12. Native background permission and battery duty-cycle need cross-device QA and store disclosures.
13. Long-press meet-up pin and one sponsored map pin are development-document concepts; do not add ads to sharing/safety controls or implement sponsorship until separately scoped.

## Planned work, not performed

**Stage 2 — Laravel/backend/admin:** introduce disabled-by-default M10 flag, audited share lifecycle and schemas, scoped ingest, authorized marker query, revoke/invalidation and erased data policies, operational health admin without raw GPS, narrow tests for block/expiry/precision/Ghost/device trust.

**Stage 3 — Flutter on THIS consolidated branch:** real MapLibre surface under existing Orbits UI, typed location repository, contextual OS permissions, explicit sharing sheet and review, server-backed markers/freshness, privacy-aware cache, logout/Ghost revocation, no demo people in authenticated live flow; focused tests and native build verification.

**Stage 4 — device/production gates:** revoked-permission and block/leave tests, approximate coordinate projection, freshness/staleness, power/background use, smooth pan/zoom/clustering, retention/log redaction, native policy compliance, real Redis+WSS+tile provider and Hostinger reachability, staged flags and rollback.

### Acceptance cases (minimum)

A01 unauthenticated access denied; A02 trusted device enforced; A03 read map without GPS permission; A04 no public/unrelated people; A05 cross-Circle isolation; A06 block/revocation no REST/GPS; A07 no socket leak post revoke; A08 precise only to approved scope; A09 approximate materially coarser; A10 nobody/hidden no position; A11 global Ghost no fallback; A12 Circle Ghost isolation; A13 one-hour expiry; A14 tonight expiry/DST; A15 leaving event after defined geofence; A16 manual revoke idempotent; A17 network offline staleness; A18 device OS permission revoked; A19 timestamps/skew/replay; A20 multi-device owner/account switch; A21 cache expunged after logout; A22 no logs/analytics GPS; A23 account erasure; A24 map performance, battery budget; A25 no map ads during sensitive controls; A26 unsupported infra never claims live.

**Stage 1 completed as a specification/architecture audit only.** The full 59-row traceability and expanded report are packaged in the conversation artifact `Orbit_M10_Stage1_Complete_Pack_2026-10-27.zip`. No Stage 2 or Stage 3 code was changed in this commit.
