# Orbit M10 — Stage 3 existing Flutter UI integration

Branch: integration/m2-m5-flutter-consolidated-2026-10-24 (no new branch).

* Existing Orbits screen and draggable sheet kept. Demo/test-only OrbitScreen.demo stays available; authenticated Home's Orbit/Explore navigation uses OrbitScreen.live instead.
* No fabricated people, fake live badge, coordinates from static map X/Y or demo direct chat.
* M10 trusted-device API client and strict typed viewer-scoped markers, guarded by ORBIT_M10_LOCATION_ENABLED=false default.
* MapLibre native interactive tiles only with explicitly supplied HTTPS ORBIT_M10_MAP_STYLE_URL; no unlicensed map vendor or fallback to public demo tile provider.
* Location share confirmation reuses M5 full-width Orbit sheet and existing Orbit popup. Recipients from real M4 friends / M5 Circles; scope, precision and duration reviewed and sent to backend.
* GPS request on intentional sharing, not map viewing; foreground-only stream, stop on pause/denial, server revocation and Ghost global veto. No background location permission/operation or realtime WSS claims.
* Existing Privacy Settings is the source of user privacy choices; Ghost / opt-out attempts to revoke grants.
* Server M10 stage2, auth and feature flags are prerequisites for any live data; backend not deployed/activated.
* Until leaving is conditional on backend approval; secure geofence processing is server-side.
* Native Android permissions coarse+fine, iOS when-in-use disclosure, MapLibre/geolocator/flutter_timezone dependencies.
* No production release claim. Verify physical devices, map tile license/contract, JDK 21 native MapLibre build, iOS Xcode/Pods and M10-specific CI, then staged server activation after sign-off.
