# Orbit M10 — Stage 4 device and release gates (2026-10-27)

Scope from original Stage 1 PRD-050–056 and A01–A26. No new branch; no production rollout.

## Safeguards
- Keep M10 API and M5 location consumer disabled on Hostinger until explicit approval.
- Keep Flutter M10 rollout off by default; do not set an unapproved tile style.
- Keep Redis/WSS and geofence disabled; no claim that refresh polling is LIVE.
- No location history, advertising pins, or background GPS permission is approved.
- Existing Orbits layout and native Orbit sheets remain unchanged.

## Automated evidence
- M10 Flutter analyzer and five focused tests passed on Stage 3 commit 1589541625e34683484ab3dbc73c1fa2ff07b81c.
- iOS simulator native compile passed on Stage 3 commit 558a98736ec7e8cc047688b3a5c80b5144a730b4.
- M10 Laravel focused tests passed after Stage 4 user-erasure fix (commit 50f8191eb2694aaa2855fa0f84fcb18a0ca4f9e4).
- Initial Android build failed because MapLibre requires Java 21. Stage 4 changed existing M4/M7 CI JDK to 21; latest native build result must be checked.
- Automated checks are not evidence of functioning physical GPS, Hostinger release, or battery lifetime.

## Required physical device and privacy test matrix

| Stage 1 case | Acceptance observation | Gate |
|---|---|---|
| A01–A02 | Anonymous, revoked session and untrusted device denied | Backend CI |
| A03 | Authorized viewer sees map without granting own GPS permission | Device |
| A04–A05 | Only consented friends and Circle members appear; never outsiders | Backend CI + device |
| A06 | Block, removal, archive and revocation remove marker | Backend CI + device |
| A07 | No location event after WSS revocation | Blocked: M10 WSS not provisioned |
| A08–A10 | Precise only where granted; approximate coarsened on server; Nobody invisible | Backend CI + approval of grid size |
| A11–A12 | Ghost gives no last-known position, global and per-Circle | Backend CI + device |
| A13–A16 | One-hour, tonight/DST, departure and manual-stop durations | Backend CI + product decisions + device |
| A17–A18 | Offline/airplane mode and OS permission revoked never create false LIVE | Device |
| A19 | Stale, replayed, skewed or inaccurate samples denied | Backend CI |
| A20–A21 | Two devices, logout, app pause and account-switch never retain GPS | Device |
| A22 | No coordinates in app/host HTTP/crash/admin logs | Security audit |
| A23 | Recipient grants and owner encrypted samples purged on deletion | Backend CI |
| A24 | Map pan/zoom, pin overlap or clustering, memory, CPU, battery | Device; clustering unverified |
| A25 | No sponsored location pin in consent or SOS workflow | Code review |
| A26 | Unverified infrastructure never displays LIVE | Code review + device |

## Device QA — no simulated PASS
Test on one physical Android (including Infinix) and one physical iPhone:
1. Use an authorized staging backend with real test accounts: owner, permitted friend, outsider; two Circles and a blocked member.
2. Test foreground location permission, Android approximate versus precise, iOS while-in-use, Settings revocation, phone lock/unlock and return to foreground.
3. Test 1 hour, tonight timezone boundary, manual stop, block/unfriend and account switch. Only run until-leaving after separate radius/hysteresis sign-off.
4. Disconnect networks while sharing; no old coordinate may be labelled LIVE. Test 120-second latest TTL.
5. Verify Android and iOS native compilation on final SHAs and inspect Android Battery Historian / Xcode Instruments for measured power. No numerical battery budget is yet approved.
6. Inspect authenticated viewer map, GPS request, Laravel/webserver/admin logs for redaction and authorization.
7. Verify tile style HTTPS, attribution, licence, rate limits, keys, provider billing and permitted offline tile caching.
8. Verify Circle privacy state, M5 access consumer and M9 Ghost precedence; do not infer consent from membership.

## Deployment safety / rollback checklist — NOT performed
1. Obtain signed acceptance of API/Realtime contract, precision grid, expiry/DST semantics, location copy, geofence and map service.
2. Provision and verify target hosting, HTTPS tile provider, credentials, trustworthy WSS/Redis **or approve explicitly non-live mode**; do not pretend Hostinger shared hosting supports unverified services.
3. Back up schema and test additive M10 migration in a dedicated staging database while flags remain OFF; verify app key and encryption settings.
4. Validate signed app identity and both physical devices; inspect logs for sensitive data; review retention command scheduler (not running in production).
5. After signed security/product/device QA, enable only the staging API and M5 location consumer for a restricted cohort. Keep realtime and geofence OFF until separately verified.
6. Test all revocations, Ghost, erase, rate limits, session trust and rollback; record source SHAs and results.
7. Emergency rollback: disable M10/M5 location consumer server switches FIRST, invalidate live recipients and delete active/latest records under a reviewed privacy procedure, halt new GPS writes; do not restore an old database backup that resurrects revoked grants.

## Release blockers
- Physical-device GPS permission, battery, background/foreground, clustering and native build acceptance unfinished.
- No approved map tile provider.
- No verified location WSS and Redis/Valkey on Hostinger. Last recorded Redis connection refused.
- Original separate API & Realtime Specification not supplied; Stage 2 endpoint names are provisional.
- No policy sign-off for precision grid, location staleness classification, geofence threshold, tonight timezone/DST and background GPS.
- Production feature flags OFF, production migrations NOT run, production deployment NOT authorized.

**Release decision: HOLD. Do not enable production M10 or imply Stage 4 device acceptance has passed.**
