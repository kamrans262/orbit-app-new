# Orbit M10 — end-to-end coding handoff (2026-10-27)

## Existing consolidated branches, no production rollout
- Flutter: kamrans262/orbit-app-new, integration/m2-m5-flutter-consolidated-2026-10-24.
- Laravel: kamrans262/orbit-backend-new, feature/m9-presence-backend-admin.
- Work uses the original Orbits map + draggable people sheet and existing Orbit buttons, sheets, confirmations, avatar widget and theme. No new replacement design.
- Demo people/images are not returned in authenticated Orbits. Only fresh authorization-filtered, server-quantized GPS markers are rendered.

## Code delivered
- Interactive native Google Maps SDK map uses Flutter OrbitMapMarker widgets at projected latitude/longitude; nearby pins group in zoomable clusters; shows real permitted account names and verified update/paused text, not fictitious LIVE badges.
- Real user profile photos: owner-only M6 AES-GCM avatar stays encrypted; optional per-person consent rewraps ONLY the content key to trusted friend's device public keys. No plaintext image upload or public URL. A separate M10 grant linkage requires the same active location share; encrypted media grant revokes on stop, expiry, geofence, unfriend or block. Without explicit consent or without the recipient device envelope, the existing Orbit initials fallback shows instead.
- Existing Privacy Settings and share sheet control audience, precision, duration, global Ghost and OS permissions. Permission denied, untrusted device, authorization errors, account swap, app background and network failures fail closed. On-device decrypted photo buffers and Flutter image-cache entries are purged at privacy transitions. While-moving uploads require observed speed at least 1 m/s on client AND backend; threshold provisional pending product review.
- Authenticated M10 REST APIs for viewer-scoped map, own share listing, create, revoke/stop, samples, gated exit geofence.
- Optional M10 realtime: Laravel viewer-device ticket (TTL 60 sec) and introspection; private Redis viewer-HMAC invalidations with no coordinates; separate loopback-only Node WSS gateway; Flutter client requests a fresh ticket and refetches authorized REST map on each event. Server auth rechecked for every event. The 20-second REST fallback remains explicitly non-live.
- Direct block/unfriend, Circle remove/leave/restrict/archive/location permission revoke, global Ghost or changed visibility permanently revoke/recheck grants rather than silently restoring old audience access.
- Latest code includes Android JDK21 native-build configuration and Google Maps SDK, iOS when-in-use permissions, geolocator foreground-only. No background location tracking has been authorized.
- Additional focused Flutter and MariaDB regression tests for actual avatars, encryption consent/revoke, trust, map markers, realtime tickets, Ghost, visibility changes and moving-only samples.

## Google Maps integration — confirmed by user (2026-10-28)

Google Maps Platform is the chosen provider. The native official
`google_maps_flutter` SDK replaced MapLibre. This is NOT a Google Maps
JSON style URL; the legacy `ORBIT_M10_MAP_STYLE_URL` and
`ORBIT_M10_MAP_API_KEY` settings are no longer used.

**Enable billing and Maps SDK for Android / Maps SDK for iOS in the same
Google Cloud project.** Create two differently restricted API keys if
you want both Android and iOS:
- **Android**: Cloud Console application restriction = Android apps,
  application ID `com.example.orbit_ui` for current debug build or the
  actual release `ORBIT_ANDROID_APPLICATION_ID`, plus that signing
  certificate's SHA-1. API restriction = Maps SDK for Android.
- **iOS**: application restriction = iOS apps using the actual Runner
  bundle identifier. API restriction = Maps SDK for iOS.
- A key restricted to Android cannot authenticate the iOS SDK and vice
  versa. Do not paste keys in GitHub, Flutter source, CI logs, or chat.
  Mobile keys are extractable from distributed builds; provider-side
  restrictions and quotas are essential.

### Untracked local Android key

Create `android/secrets.properties` on your development machine:
```properties
ORBIT_GOOGLE_MAPS_ANDROID_API_KEY=YOUR_ANDROID_RESTRICTED_GOOGLE_MAPS_KEY
```
This path is Git-ignored. Gradle also accepts environment variable
`ORBIT_GOOGLE_MAPS_ANDROID_API_KEY` for authorized CI/build machines.
The Android manifest only contains a manifest placeholder, never a key.

### Untracked local iOS key

Create `ios/Flutter/GoogleMapsSecrets.xcconfig` locally:
```xcconfig
ORBIT_GOOGLE_MAPS_IOS_API_KEY=YOUR_IOS_RESTRICTED_GOOGLE_MAPS_KEY
```
This path is Git-ignored. The existing Debug/Release xcconfigs include
it optionally. AppDelegate reads the resulting Info.plist entry and
registers `GMSServices.provideAPIKey` before Flutter plugins start.
When no key is supplied, startup remains safe and M10 shows a static
preview because the rollout is off. No key is committed.

### Flutter flag for authorized staging test only

Create the existing ignored `.orbit_m10_local.json` with no secrets:
```json
{
  "ORBIT_M10_LOCATION_ENABLED": "true",
  "ORBIT_M10_GOOGLE_MAPS_CONFIGURED": "true",
  "ORBIT_M10_WSS_URL": ""
}
```
After provisioning the appropriate native key file, use
`flutter run --dart-define-from-file=.orbit_m10_local.json` for a
reviewed staging test installation. **The Flutter flag is not sufficient
without a native key.** Production M10 stays OFF; no real phone or
Google API call was performed by this integration.

Google Maps widget does not request viewer GPS and does not receive
plaintext Orbit avatars; existing Flutter OrbitMapMarker widgets are
rendered over viewer-authorized positions. Do not cover Google's logo,
legal notices or standard attribution in revised screen layouts.

## Plain `flutter run` after consolidated Circle UI integration (2026-10-28)

- The restored original Circle UI branch `feature/restore-original-circle-ui-2026-10-27` was merged into the consolidated Flutter branch, including its later friend, profile, invite and Moments camera edits. Its history is preserved as the second parent of the merge commit.
- M7 Moments, M8 Home, M9 client UI and M10 foreground Google Maps UI default ON in normal builds. Use **`flutter run`**, without `--dart-define`. Existing per-flag `--dart-define=...=false` rollback remains available.
- The approved Google Maps API key is still a **required native Android/iOS credential** and is read only from untracked `android/secrets.properties` or `ios/Flutter/GoogleMapsSecrets.xcconfig` (or secured native build environment); no provider secrets are committed.
- GoogleMap is only initialized after the private backend capabilities request confirms authenticated access. Before that, the existing static map preview is displayed. This avoids unauthenticated map activation.
- Hostinger server `ORBIT_M10_LOCATION_ENABLED` is an independent server-side switch and can remain OFF. A Flutter default does NOT activate the server, GPS uploads, any share, permissions or Ghost Mode. All location audiences require explicit privacy enablement plus reviewed per-audience consent.
- M9/M10 WSS URLs default empty. Without verified managed gateway + Redis, **realtime remains disabled**; neither status nor location may be called LIVE merely because UI flags are true.

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
- Real provider key restrictions, billing, map tiles on real Android/iOS, production gateway/TLS/Redis service, API/Realtime
  Specification product sign-off, DST/geofence/approximate-grid policy approval,
  and staging/prod operational backup/rollback remain EXTERNAL prerequisites.
- Do not enable production flags, deploy PHP migrations to Hostinger, enable
  Firebase, expose private GPS logs or claim LIVE without verified WSS health.
- Original `docs/M10_STAGE4_DEVICE_RELEASE_GATES_2026-10-27.md` remains the
  acceptance matrix and staged rollback authority.

**Code paths implemented; launch/physical device/realtime infrastructure NOT certified.**
