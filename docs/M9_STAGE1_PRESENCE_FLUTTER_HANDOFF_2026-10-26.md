# Orbit M9 — Stage 1 Flutter Presence handoff
Date: 2026-10-26. **Documentation/architecture only. No UI code is claimed implemented.**
Branch: `feature/m9-presence-flutter`, based on consolidated M2–M7 Flutter. M8 Home is in a separate branch/chat: do not edit it or overwrite its pending work.

## Scope
The client PRD calls for permission-controlled Active now/Recently active (PRD-095/096), typing state (PRD-072) and presence invisibility after blocks (PRD-105). The internal development source specifies per-Circle Presence, global Ghost precedence, 90s server lease TTL, 5s typing state expiry and 3s typing throttle. Exact source mappings are retained in the companion Stage 1 matrix.

## Planned Flutter architecture
- A feature-gated `PresenceRepository` and lifecycle-aware `PresenceCoordinator` use existing Orbit API/auth/device infrastructure, one subscribed realtime connection per app instance where supported, and a normalized `PresenceViewState`.
- UI must never infer current online from stale M8 cached dashboard payload: after expiry show stale/unknown/offline safely, and clear protected presence on block, removal, Ghost, consent revocation and account logout.
- Provide per-Circle scoped state to existing Circle cards, Member Detail, Friends/Circle consumers and later M8 Home (online dots only when server-authorized). Never modify M8 branch from M9 chat.
- Global/per-Circle controls reuse the **existing** Orbit header, inputs, popups, snackbar, spacing, icons and typography. Do not invent a new visual system.
- Optional Home/Work/Gym/Driving/Traveling labels are sourced from later M10 location/verified user context, not mock or guessed coordinates.
- Ephemeral typing indicator integration is compatible with later M13 E2EE messaging; send no message plaintext through Presence.
- Ghost suppresses live visibility under current Circle policy but does not disable SOS, messages or Moments.
- Foreground/background, OS kill, reconnect, airplane mode and multi-device results require native-device acceptance. No unapproved permanent background socket claim.

## Integration and external gates
- M9 Stage 2 backend waits for M8 backend API and migrations to stabilize; M9 Stage 3 Flutter adapts to M8 Home contract only after review.
- REST polling is NOT equivalent to the client's Redis/WebSocket presence requirement. A verified realtime gateway is needed for p95 latency and battery acceptance.
- Missing standalone API & Realtime spec and global-Ghost badge ambiguity remain open decisions.
- Stage 1 complete means documents/plan only; Stage 2, Stage 3, Stage 4 are not implemented or tested.
