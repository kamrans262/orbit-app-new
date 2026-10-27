# Orbit M10 — end-to-end coding handoff (2026-10-27)

## Existing consolidated branches, no production rollout
- Flutter: kamrans262/orbit-app-new, integration/m2-m5-flutter-consolidated-2026-10-24.
- Laravel: kamrans262/orbit-backend-new, feature/m9-presence-backend-admin.
- Work uses the original Orbits map + draggable people sheet and existing Orbit buttons, sheets, confirmations, avatar widget and theme. No new replacement design.
- Demo people/images are not returned in authenticated Orbits. Only fresh authorization-filtered, server-quantized GPS markers are rendered.

## Code delivered
- Interactive native MapLibre map uses Flutter OrbitMapMarker widgets at projected latitude/longitude; nearby pins group in zoomable clusters; shows real permitted account names and verified update/paused text, not fictitious LIVE badges.
- Real user profile photos: owner-only M6 AES-GCM avatar stays encrypted; optional per-person consent rewraps ONLY the content key to trusted friend's device public keys. No plaintext image upload or public URL. A separate M10 grant linkage requires the same active location share; encrypted media grant revokes on stop, expiry, geofence, unfriend or block. Without explicit consent or without the recipient device envelope, the existing Orbit initials fallback shows instead.
- Existing Privacy Settings and share sheet control audience, precision, duration, global Ghost and OS permissions. Permission denied, untrusted device, authorization errors, account swap, app background and network failures fail closed. On-device decrypted photo buffers and Flutter image-cache entries are purged at privacy transitions. While-moving uploads require observed speed at least 1 m/s on client AND backend; threshold provisional pending product review.
- Authenticated M10 REST APIs for viewer-scoped map, own share listing, create, revoke/stop, samples, gated exit geofence.
- Optional M10 realtime: Laravel viewer-device ticket (TTL 60 sec) and introspection; private Redis viewer-HMAC invalidations with no coordinates; separate loopback-only Node WSS gateway; Flutter client requests a fresh ticket and refetches authorized REST map on each event. Server auth rechecked for every event. The 20-second REST fallback remains explicitly non-live.
- Direct block/unfriend, Circle remove/leave/restrict/archive/location permission revoke, global Ghost or changed visibility permanently revoke/recheck grants rather than silently restoring old audience access.
- Latest code includes Android JDK21 MapLibre configuration, iOS when-in-use permissions, geolocator foreground-only. No background location tracking has been authorized.
- Additional focused Flutter and MariaDB regression tests for actual avatars, encryption consent/revoke, trust, map markers, realtime tickets, Ghost, visibility changes and moving-only samples.

## Local map provider — user supplies restricted key through an UNTRACKED file
Your provider-specific MapLibre HTTPS style JSON URL must be known. Create
`.orbit_m10_local.json` on your own machine (path is ignored by Git) with:
```json
{
  "ORBIT_M10_LOCATION_ENABLED": "true",
  "ORBIT_M10_MAP_STYLE_URL": "https://YOUR_APPROVED_PROVIDER/style.json?key={API_KEY}",
  "ORBIT_M10_MAP_API_KEY": "YOUR_RESTRICTED_MOBILE_MAP_KEY",
  "ORBIT_M10_WSS_URL": ""
}
```
Then use `flutter run --dart-define-from-file=.orbit_m10_local.json` on an
approved **staging** installation. Never put this file in GitHub, any screenshot,
client logs or a support chat. A mobile map key is extractable from an app
binary or network call; restrict it at the map provider by app/bundle ID, usage
scope, quota and/or provider-specific mobile credentials. No map provider/URL/key
was provided in this conversation, so no actual map vendor has been selected or
verified. The original screen displays a static map preview if style is absent.

## Laravel staging prerequisites (NOT run on Hostinger)
- Apply additive migrations `2026_10_27_000001_create_m10_location.php`
  and `2026_10_27_000002_add_m10_private_avatar_grants.php` to disposable
  staging MariaDB only after backup/approval.
- Configure server `ORBIT_M10_LOCATION_ENABLED=true` and, if Circle audience
  is approved, `ORBIT_M5_LOCATION_CONSUMER_ENABLED=true`. Both remain OFF in
  production, along with geofence and realtime.
- Existing M6 avatar owner upload must be enabled and trusted-device ready;
  friends get decrypted photos only through the new explicit per-share consent,
  otherwise initials remain.
- A WSS server + Redis are NOT optional for true realtime, and Hostinger
  shared hosting's Redis was previously connection refused. To enable realtime
  after external verification, run the optional managed gateway described in
  backend `gateway/location/README.md` with TLS reverse proxy, authenticated
  Redis and shared gateway secret. Set backend
  `ORBIT_M10_LOCATION_REALTIME_ENABLED=true`,
  `ORBIT_M10_REALTIME_VERIFIED=true`,
  `ORBIT_M10_GATEWAY_SECRET`, `ORBIT_M10_WSS_URL` and a production Redis store,
  and supply the identical approved WSS URL through Flutter build config.
  Do not toggle these values unless actual gateway lifecycle, ACL and
  revocation tests pass. Realtime falls back to secure REST while disabled.
- Map source attribution/licence and usage fees are provider-dependent.

## Remaining release acceptance (not a coding-success claim)
- Run latest commit Android/iOS native compilation and physical Android/iOS
  foreground location, deny/revoke, zoom/clustering, battery, signed app and
  multi-device QA. Automated CI cannot substitute for phone testing.
- Actual map-key licence, production gateway/TLS/Redis service, API/Realtime
  Specification product sign-off, DST/geofence/approximate-grid policy approval,
  and staging/prod operational backup/rollback remain EXTERNAL prerequisites.
- Do not enable production flags, deploy PHP migrations to Hostinger, enable
  Firebase, expose private GPS logs or claim LIVE without verified WSS health.
- Original `docs/M10_STAGE4_DEVICE_RELEASE_GATES_2026-10-27.md` remains the
  acceptance matrix and staged rollback authority.

**Code paths implemented; launch/physical device/realtime infrastructure NOT certified.**
