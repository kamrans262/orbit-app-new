# ORBIT — M4 Flutter social graph integration and acceptance gate

Status: **DRAFT, NOT DEPLOYED**. Branch: `feature/m4-social-graph-flutter` (base `feature/m3-completion-offline`).
API dependency: backend `kamrans262/orbit-backend-new` PR #7, still draft/not deployed on Hostinger.
Source: Orbit M4 Deep Requirements Audit (2026-10-20), based on PRD, TRD, flows, schema, Admin, Security, QA and internal specifications. No complete independent API & Realtime source was supplied; the contract below matches PR #7, not a fabricated signed-off document.

## Integrated feature scope

- API transport is the **existing** `OrbitIdentityClient.socialRequest()`, inheriting protected bearer authentication, refresh-token handling, trusted-device restrictions, server deletions, timeouts and safe failures.
- `OrbitSocialRepository` maps *only* returned minimal person fields. No GPS, presence, "Active now", placeholder friends, fake Circle memberships, photos or private bio.
- Authenticated **Settings → Friends** opens `OrbitLiveFriendsScreen` using the existing `FriendsScreen` / `FavoritePersonTile` design, paginated lists, inline friend search, retry/error/empty state and actions to Find Friends / Friend Requests.
- **Find Friends** searches by name **or** username with 2-character minimum, debounced and race-safe results, pagination, minimal previews and invitation options. Unavailable/blocked users don't appear.
- **Person Detail** shows only permitted identity fields and backend-confirmed friendship state; supports send, unfriend and block with confirmation. It never pretends friendship is a Circle membership.
- **Requests**: incoming/outgoing with server-confirmed accept, decline, cancel and paging. Offline or network errors show failure; no silent pending queue or false success.
- **Blocked users** in Settings and Privacy Settings use real backend lists. No fake people; unblock only changes UI after server success; errors leave block active.
- **Onboarding Invite People** sends friend discovery actions to authenticated finder after profile verification; demo nearby entries suppressed. Skip/Done still work. These do not create Circles (M5).
- Optional contact matching uses user-entered email/E.164 value with an explicit consent confirmation; no unrequested address-book permission/upload. Target must independently opt in.
- Users may turn name discovery, overall discovery, contact discoverability and friend-request permissions on/off in the authenticated Friend Discovery screen. Saving is server-confirmed.
- Invite-by-link uses Share sheet and 7-day single-use backend-generated link; redeem via private code. Native universal/app link interception, QR scanning and a system address-book contact picker require a separate platform integration before claiming those native-specific acceptance tests.
- A small M4-focused GitHub Actions workflow exercises analyzer, typed repository tests, live Friends/Blocked widget tests and the existing M3 offline profile regression.

## Explicitly deferred / release gates (not a hidden pass)

1. M4 backend isn't deployed. End-to-end two-account testing cannot pass until an approved backend staging/production deploy with database backup and additive migrations.
2. Firebase/WS realtime fanout, cache invalidation on **other devices**, presence, GPS, messaging, Moments, Ping, Circles and SOS each need their own future modules. Flutter does not invent events nor bypass the backend relation policy.
3. The detailed QA requires an owner-bound offline friends snapshot clearly marked stale. The approved M3 offline design permits **only a read-only cached profile** when offline; it explicitly denies full Home or other authenticated areas. To avoid weakening M3 security, M4 currently fails closed on unavailable API and does not expose a cached Friends screen during disconnection. Offline friend snapshot requires a distinct reviewed security design and device revocation protocol.
4. M4 native OS contacts and QR/universal-link handling are not wired in this PR. Manual contact-entry with consent and 7-day invite links work on backend but are not equivalent to native contacts/QR.
5. The existing Friends/Blocked Users visual widgets and styling are reused. Detail/request/discovery uses Orbit headers/rows, but design-system visual approval on Android and iOS remains required.
6. Do not declare M4 accepted until 35 audit scenarios have been exercised including two real accounts, pagination, profile privacy, mutual block, pending session/deletion, invite expiry, error rollback and separate device account-switch; no destructive testing on Hostinger.
7. Do **not** enable erasure processing; `ORBIT_M3_ERASURE_EXECUTION_ENABLED=false` remains the server gate. Backend review retains M3 deletion checks.

## Native integration development status (October 20 verification)

- A native single-contact picker, QR scanning/generation, and Android intent / iOS universal-link handlers are present in the M4 branch. Native camera/contact permissions must be exercised on both operating systems.
- Android and iOS HTTPS app links require domain association verification from the Hostinger domain; deployment of the well-known manifests on the backend is a separate release step, **not evidence that app links work before deployment**.
- The owner-scoped, short-lived, encrypted Friends snapshot is read-only and deliberately has no protected relationship entitlements. It is never valid authentication and cannot bypass M3's offline-profile-only session-restoration gate. Other-device block revocation cannot be guaranteed during a network outage; this remains an explicit acceptance/security constraint.
- M4 revision polling provides foreground relationship refresh; a future authenticated realtime delivery worker and transport-subscription revocation are separate from polling and must not be represented as delivered.
- All 35 audit acceptance scenarios still require closure or explicit downstream-module classification. Passing static analysis, widget tests, and Android CI build is not live two-account acceptance.

## Manual acceptance sequence after an approved backend deploy

1. Create two disposable test accounts A/B on trusted devices.
2. A opens Settings → Friends (real empty list), Find Friends and searches B by username and name.
3. A sends a request, B sees Received, accepts, then both see the correct friends. No Circle membership/location sharing granted.
4. B removes friendship; after reload both lose friend status.
5. A sends again; B declines; A sees a privacy-safe cooldown, can cancel their own pending outgoing request.
6. A blocks B using Person Detail. B cannot discover/preview/message A. A sees B in Blocked Users; unblocking removes the block but must NOT recreate friendship.
7. Test discoverability opt-out and explicit contact consent, after B opts into contact matching.
8. Create a link, redeem only once, revoke another, verify expiry on isolated test environment.
9. Disconnect internet while listing friends and performing mutation; no demo data, misleading success or unauthorized offline Home.
10. Admin Friends & Blocking counters reflect accepted requests and directional blocks; restricted admin gets 403.

**No production branch, Hostinger database, or M3 local checkout was changed by this mobile integration.**
