# Orbit M16 — Existing Mobile UI Conformance Audit

**Scope:** The pre-approved SOS Alert and Responder Map screens remain the design authority. This change is strictly a UI-component alignment on the existing M16 Flutter branch. No Laravel or deployment changes.

## Findings and corrections

| Surface | Before | Now |
|---|---|---|
| SOS activation | Original SOS Alert / 3-second hold | Preserved |
| Responder map | Original responder screen and existing Orbit popup | Preserved |
| Contacts management | New generic Flutter `Card` and `ElevatedButton.icon` | Existing `AppScreenHeader`, `AppPrimaryButton`, `OrbitCircleSheetAction`, `showOrbitCircleSheet`, `OrbitPopupModal` |
| SOS Alerts history | New rounded `Material` container wrapping a `ListTile` | Same `ListTile`, `Divider`, `AppTypography.body/bodyMuted`, and `AppScreenHeader` style as approved M14 Notifications |
| Emergency dialing | Generic `TextField` in Orbit popup | Existing `AppTextField` inside the same approved `OrbitPopupModal` |
| Unconfirmed SOS actions | New inline `Wrap` with multiple text buttons | Existing single text action + shared `OrbitPopupModal` primary/secondary actions |

No new design tokens, typography systems, popup frameworks, custom bottom-sheet containers, navigation bars, or button variants were introduced by the alignment.

New *data-driven functional routes* (contact management and SOS history) remain because the SOS backend exposes new resources; they are built from established Orbit presentation components rather than new design patterns.

Backend acceptance, provider push acceptance, responder acknowledgement, recording availability, and offline uncertainty semantics remain unchanged.

## Verification

- `dart analyze` and focused Flutter UI tests are provided in M16 CI.
- `test/features/sos/orbit_m16_approved_ui_test.dart` asserts the shared component reuse and no generic cards or ElevatedButtons.
- Keep the standard SOS screen tests, M8 Home, M14 Notifications, M15 Plans regressions, and Android CI build in the same workflow.
- Device-level screenshot review still requires a Flutter device/emulator, and live emergency dispatch must not be claimed.
