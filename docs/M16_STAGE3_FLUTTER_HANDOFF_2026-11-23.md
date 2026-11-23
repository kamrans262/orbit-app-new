# ORBIT M16 Stage 3 — Flutter implementation and review handoff

**GitHub:** `kamrans262/orbit-app-new` / `feature/m16-sos-safety-flutter-2026-11-23`  
**API baseline:** Laravel `feature/m16-sos-safety-backend-admin-2026-11-17`  
**No production deployment or device release.**

## Approved UI preserved

Existing SOS alert (3-second hold, dark palette, trigger rings, quick-action icons) and responder map UI remain the visual baseline. New data-only services use M2 trusted-session HTTP and the existing Orbit popup and Circle sheet patterns. Home's existing SOS action routes to the real screen, and server-authorized incoming SOS can open the same responder UI. Private incident status must never be fabricated.

## Stage 3 contract

- User hold (3 seconds) creates `POST /api/v1/sos/incidents` with explicit confirmation, a stable `client_id`, server-selected primary Circle when available, and accepted trusted contacts. No GPS is transmitted until explicitly opted in.
- Contact list management uses `GET/POST/DELETE /api/v1/sos/trusted-contacts` and recipient acceptance; only server-confirmed relationships render as accepted.
- Backend incident reads, responder acknowledgement, cancel and resolve all use current trusted-user credentials. Resolve and cancel use the latest server revision. Location is read from the protected endpoint, never from unrelated M10 or demo assets.
- The optional SOS map uses only fresh authorized coordinates; it disappears when expired, revoked, hidden/backgrounded, or the account changes. No fabricated live ETA or responder positions.
- Calling emergency services opens the device dialer with a manually provided local number. It does not claim Orbit has contacted any service. Recording consent does not activate recording because the M16 backend cannot handle audio yet.
- On uncertain network failure, persist the exact request for a short period in OS secure storage and **never auto-retry or claim delivery**. Manual retry uses the same client ID and same location sample; stale coordinates cannot be replayed.
- SOS may register and remain unacknowledged; server acceptance, FCM provider acceptance and responder acknowledgment are distinct in the UI. M16 push requires independently configured Firebase; the generic FCM notification contains no private coordinates.

## Verification / remaining Stage 4 gates

Run the dedicated CI workflow for Dart analysis, SOS widget and contract tests, M8/M14/M15 integration regressions, and an Android debug build. Real iOS/Android foreground/background push, FCM taps, network loss during send, simultaneous trusted responders, permission revocation, and live physical GPS remain device-level release gates. Flutter cannot make SOS dispatch while entirely offline: M22 Relay is not implemented. The PRD's auto-recording versus explicit consent conflict remains open. Production migration/deployment requires separate authorization.
