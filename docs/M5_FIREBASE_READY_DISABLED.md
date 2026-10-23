# Orbit M5 — Firebase bridge prepared, not active

**No Firebase client project or activation is required for normal M5 builds.**

The code includes a secondary Firebase app/Realtime Database listener only for Orbit M5 Circle revision metadata. It never contains location, chat, Moments, presence, membership rosters or any SOS content.

## Defaults and commands

Normal QA/debug builds require nothing beyond the existing Flutter dependency installation.

    flutter pub get
    flutter build apk --debug

The compile-time Firebase gate is FALSE by default. With client credentials *after future authorized rollout*, an explicitly opted-in build can use:

    flutter build apk --debug --dart-define=ORBIT_M5_FIREBASE_ENABLED=true

This define alone does not activate the service: Laravel must also have M5 and Firebase flags enabled, a service account, public Flutter options and correct RTDB rules installed. Until then, the backend bootstrap endpoint returns 404. The 25-second authenticated Circle refresh remains active. Do NOT enable the define before QA security sign-off.

On approved activation, Flutter requests a 15-minute Firebase custom token from an already trusted Orbit device session, signs into a distinct secondary Firebase app, listens ONLY to a Circle revision integer and calls Laravel for every actual Circle refresh. Permission-denied errors prompt Laravel reauthorization. Account logout, user switch and erasure cancel listeners and sign out of the secondary Firebase app. No Firebase event is authoritative for protected content or membership.

The corresponding server rules and rollout documentation are in the backend branch files firebase/database.rules.json and docs/M5_FIREBASE_READY_DISABLED.md. Deploy restrictive rules only to the matching approved Firebase project.

## Remaining external acceptance

Before claiming realtime completion, use two trusted *physical* Android/iOS devices, actual client Firebase configuration, and approved server switches. Run live join/leave/block/role-change/logout/session-revoke/device-revoke while a database listener is running. Prove immediate permission denial or subscriber cancellation without relying on foreground polling. Test bad/expired tokens, offline/reconnect and replay. Revisions may be cached, but the app cannot display private Circle content without Laravel reauthorization.

**Signed builds:** Android release fails closed without a real application ID and signing material. iOS still contains the placeholder com.example.orbitUi; final Bundle ID, Apple Team signing and associated-domain verification must come from signed physical-device builds, not fabricated source values.

**Scope:** Later Moments, map/location, presence, messaging, Ping and SOS consumers must each call backend Circle access policy at every data boundary. Circle membership alone does not grant sharing.
