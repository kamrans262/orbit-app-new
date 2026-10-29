# Orbit Ping — Flutter Stage 3 implementation

**Existing consolidated branch:** \`integration/m2-m5-flutter-consolidated-2026-10-24\`.

## Reused screens and components

- **PingScreen.demo** retains its six option cards and existing Custom Message entry, but now uses the approved \`showOrbitCircleSheet\` for Custom Message and About Ping. Missing callback/recipient never shows a fake send confirmation.
- **Home quick action Ping** and **central + Ping action** launch an existing \`showOrbitCircleSheet\` friend picker, then reuse the unchanged PingScreen.
- **Person Detail Ping** reuses the existing SettingsListItem action for verified friends.
- **Circle Detail member sheet** reuses its existing action-row style for Ping to another member, plus confirmed consent on the user's own member tile.
- **Incoming Ping** reuses the full-width Orbit Circle sheet with “Hey” and the original explicit-consent Location Share sheet (no coordinates leave the device without its own approval flow).
- **Sent Pings** are shown in an existing Orbit sheet with server-reported Accepted, Delivered and Seen (when permitted). No new standalone design.
- All statuses use the app’s existing gradient snackbar infrastructure.

## Privacy and transport

- Authenticated \`OrbitIdentityClient.socialRequest\` is the only network transport. The same trusted-device tokens, refresh and denial handling apply.
- Offline intent is securely saved under the authenticated owner with a stable UUID before send, and retried on foreground Home refresh; non-retryable permission denials are removed. The local queue is wiped on sign-out/account switch.
- A 201/200 send response means **Accepted**, never Delivered. Only a successful recipient receipt permits Delivered; Seen is recorded after the incoming sheet has been viewed/dismissed. Sender read receipts remain under the backend privacy policy.
- \`GET /pings/capabilities\` ensures the UI does not pretend the feature is connected if the backend migration is absent.
- Circle consent uses the Stage 3 companion API, which requires a trusted member device, global \`My Circle\` Ping privacy and explicit confirmation.

## Operational prerequisites (not run)

- Deploy backend commits including the Ping schema and self-service consent API. Run the DB migration.
- Verify the authenticated Ping endpoints on the actual Hostinger deployment.
- Run focused Flutter tests: \`flutter test test/features/ping\` and an Android debug build on the existing branch. Flutter tooling is unavailable in the current tool runtime; no native build or end-to-end delivery is claimed.
- Background push and instant websocket delivery are not provisioned. Home foreground refresh is not the same as realtime.
- No extra repository or branch was created; existing approved Orbit components remain authoritative.
