# Orbit M5 — Stage 3 Flutter requirements re-audit and release gate
**Basis:** `Orbit_M5_Complete_Requirements_Audit_2026-10-21.md` (134 requirements, 28 decisions, 40 numbered CT acceptance cases); `orbit-backend-new/docs/M5_STAGE2_APPROVED_POLICY_AND_FLUTTER_API_HANDOFF.md`; original PRD/TRD/workflows/security/QA as mapped in the master M5 audit.
**Branch:** `feature/m5-circles-flutter-integration` from M4 `70fae1bda0865d411c248240a384134f40d28e9e`. **Backend:** separate draft M5 PR #10. **Production:** M5 not deployed. **Do not merge or enable flags without full sign-off.**
**Priority:** Original Orbit product-facing PRD and approved conservative privacy policy; don't silently invent sharing, temporal retention, Firebase or paid entitlements.

## Stage 3 traceability to audited requirement IDs
| IDs | Implementation/evidence | Remaining sign-off |
|---|---|---|
| M5-008–010 | New authenticated Join with Code and QR screen, Create with approved design, Skip, Profile > My Circles, name/color/icon validation | Exact onboarding visuals on devices |
| M5-011–013 | Explicit pre-create privacy confirmation; create waits for authenticated server 201; sole-owner server transaction | Two-account/device verification |
| M5-014–017 | Targeted friends-only invitations (no autojoin), code copy/share, real Circle Detail after onboarding, Home-root exit; stable create Idempotency-Key survives token refresh | Cold-start native link and actual share-sheet QA |
| M5-018–026 | Owner rename/color/icon, Member leave, role and transfer controls, owner archive/restore, primary selection, app refresh after confirmed changes | Visual QA; role changes must be server-verified with two devices |
| M5-027–039 | Strict 40-character one-recipient invite, preview and JOIN dialog, QR scanner, sent/pending/accepted, incoming accept/decline, revoke visibility now server-computed can_revoke | Native App/Universal Links association, camera tests, rate-limit E2E |
| M5-040–050 | Paginated private roster, only allowed member details, four-role capabilities from backend; restricted cannot manage | **Policy exception**: conservative Owner-only member removal; Admin cannot remove until explicitly approved |
| M5-051–064 | Sharing is default OFF; disabled / nonfunctional UI toggles never claim to grant location, presence, chat, Moments, Ping, or SOS | Live precision/duration/ghost/realtime consumers remain later-module integrations and **not completed** |
| M5-065–072 | Existing M4 block and server per-action ACL gate; no private roster offline; recipient-bound invite and safe error path | Foreground realtime revocation needs Firebase/WS and channel reauthorization |
| M5-073–079 | Never silently create temporary expiry, retention purge, or SOS defaults | Unapproved temporary lifecycle and downstream SOS remain **deferred** |
| M5-080–083 | Demo My Circles replaced with real HTTP list, search, empty/loading/error; real create/join and member roster | Device/screenshot parity |
| M5-084–085 | No made-up Circle map/chat/feed; Group tab hidden on live detail | Future scoped map/chat integration intentionally gated |
| M5-086–089 | Server-authorized owner settings and icon, pending invite states, restricted member previews, hide nonpersistent favorites | QA with owner/admin/member/restricted accounts |
| M5-090 | Reuses Orbit typography/colors/cards and existing create, detail, Settings, invite management screens | Approved Figma screenshot comparison still **pending** |
| M5-091–109 | Backend PR #10 is source of truth; mobile uses M4 auth and central network/error handling and backend pagination; create idempotency supplied from form | Backend throughput, MariaDB and production migration verification are separate release gates |
| M5-110–112 | Encrypted account-bound 15-min names-only cached snapshot; stale label, no member counts, no offline mutations, cleared on logout/account switch | Offline on physical device with two accounts |
| M5-113–116 | No simulated realtime or push; refresh on navigation/resume, server rejects unauthorized mutations | **Deferred until Firebase/authorized realtime transport and security checks** |
| M5-117–123 | Admin scope owned by backend Stage 2 PR #10; no mobile admin bypass; no Stripe dependency | Backend Admin visual/RBAC acceptance separate |
| M5-124–134 | Flutter API/ACL/cache tests and existing Circle/M4 suites, backend MariaDB CI | Manual CT-01–40 matrix, Android/iOS device, admin, regression, load, signed-link and backup/deploy review |

## Stage 3 code ownership
- `lib/features/circles/data/orbit_circle_repository.dart`: typed M5 API, 4-role capabilities, recipient code parse, mutations, 7-day policy, authenticated M4 client.
- `lib/features/circles/data/orbit_circle_snapshot.dart`: sanitized per-user read-only cache. `orbit_identity_client.dart` owns secure storage, refresh, cleanup and idempotency header.
- `orbit_live_circles_screen.dart`: server page list and recipient invitations; `orbit_live_circle_detail_screen.dart`: real roster/no mock chat; `orbit_live_circle_settings_screen.dart`: server writes or rollback; `orbit_live_circle_manage_screen.dart`: role action matrix and primary selection.
- `orbit_live_create_circle_screen.dart`, `orbit_circle_join_screen.dart`, `orbit_live_invite_member_screen.dart`, `orbit_live_circle_invites_screen.dart`, `orbit_live_archived_circles_screen.dart`, `orbit_circle_qr_scan_screen.dart`: production-facing flows.
- `lib/core/navigation/orbit_invite_link_runtime.dart` handles cold/warm start only after trusted Home session; OS metadata is prepared but verification requires final app ID/signing and domain association.

## Original CT-01–CT-40 acceptance status (truthful)
**Implementation covered, manual E2E not yet executed:** CT-01–12, CT-14–20, CT-24–29, CT-35–38. Tests on repository and emulator widgets do not count as real-device acceptance.
**Changed by approved conservative policy:** CT-13 (Admin member removal is disabled; Owner only), CT-21 (per-Circle active sharing remains deny-all; schema exists), CT-23/CT-32 (temporary expiry/retention not approved).
**Dependency/policy deferred:** CT-22, CT-23, CT-30, CT-32, CT-39; CT-31 code exists but verified universal/App Links and signed-out manual cold-start still untested.
**Release/admin gate:** CT-33, CT-34, CT-36–37 and CT-40 require backend/admin/production evidence; do not mark them passed by mobile CI alone.

## Mobile tester walk-through (not yet executed)
1. Register/log in trusted A. Navigate Profile > Settings > My Circles. Verify clean empty state, search, Create and Join; never demo Emma/Mike/Sophia.
2. Create named Circle. Review OFF-by-default privacy; confirm. Verify one owner and real Circle Detail; navigate Back to Home and reopen Circle by same UUID.
3. Create second Circle; verify independent names/counts and no cross-Circle leakage.
4. A and B accept friendship first. From A's Circle Detail choose Add Member > select B > Invite. Verify one-time code and QR; B does **not** automatically join.
5. B enters code / scans QR / follows official link; preview is safe and requires confirmation. Decline, cancel, expire, wrong-recipient and replay must deny, with no membership mutation.
6. B accepts on a new invitation; verify B joins roster and A sees accepted status; list refresh after navigation and app resume.
7. Test four roles with accounts A/B/C/D. Owner can edit/remove/change role/transfer/archive; Admin can invite and revoke **own** invites; Member/Restricted cannot manage.
8. After Block/unfriend, confirm invite and roster revocation on server with no leaked stale details; verify no friend recovery on unblock.
9. Member leaves and returns to Circles list; owner archives and restores (pending invites stay revoked); change primary and verify fallback.
10. Switch offline with a recent snapshot: names-only, labelled stale, no counts/roster/secret code/mutations. Sign out, switch users and verify no account bleed.
11. Test 320/360/390/430 width, Android and iOS, long names, keyboard dismissal, sheet position, Circle Settings visual parity, camera permission, Back/Home navigation.
12. Check Native URLs only after final Android applicationId, signing SHA256 assetlinks.json, iOS bundle/team-ID AASA and domain deployment. Deep-link source validation alone is not native verification.
13. Compare app screens to approved Figma; independently exercise M1-M4 sign-in, profile, offline profile, Friends/block tests.
14. **Do not deploy M5** until backend PR #10 plus mobile PR #6 pass CI on exact final SHAs, Admin QA, production backup, migration pretend, and user sign-off.

## Nonclaims / data safety
- No Firebase/WS realtime delivery or active subscriber revocation; Flutter refresh is not a security mechanism. Laravel remains authoritative.
- No location/moment/chat/SOS opt-in or downstream read-grant enforcement is implemented here. No false "enabled" badges.
- No actual Circle user content, precise coordinates, secret codes or roster in the offline snapshot.
- No Hostinger migration, data reset, erasure, rollback, Flutter store release, or merge was authorized by Stage 3 work.
