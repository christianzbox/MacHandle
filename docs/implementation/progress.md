# Implementation progress

Updated: 2026-10-29. This file records actual implementation and evidence, not the
planned feature inventory. For current branch/PR/next action read
[coordination](pr-coordination.md); for planned scope read the [PR roadmap](pr-roadmap.md)
and [master implementation plan](../../plans/MacHandleMasterImplementationPlan.md).

## State definitions

| Dimension | Meaning / evidence required |
| --- | --- |
| Planned | Requirement/work package exists; code and tests are not implied. |
| In progress | Active unfinished implementation or review work, identified in coordination. |
| Implemented | Named code/docs exist on a branch; separate from validation, merge and release. |
| Verified | A scoped check passed on an identified snapshot/toolchain, with limitations. Synthetic tests do not prove live services or another physical Mac. |
| Deferred | Explicit decision, reason, owner and revisit trigger; retain the requirement. Conditional planned work is not a deferral verdict. |
| Merged | GitHub confirms merge and provides the actual merge commit. Open/review-ready/tested does not mean merged. |

## Implemented versus planned

| Area | Implemented now | Verification | Merged / release |
| --- | --- | --- | --- |
| PR-01 native foundation | Minimal SwiftUI window, local Swift package presentation metadata, shared Xcode scheme; no third-party runtime dependencies | Debug/Release builds, package test, formatter and analyze action at checkpoint below | Merged in PR #1; no release |
| PR-01 repository safety | Synthetic fixtures, indexed-file privacy checks, pinned Gitleaks, least-privilege CI, templates and ignore rules | Privacy tests, history/index scans and hosted checks at checkpoint below | Merged in PR #1; repo settings separately verified |
| PR-01 interchangeable Macs | Exact toolchain config/preflight, custom paths/discovery, clean-clone setup, Git handoff, shared AGENTS/Codex discovery | Strict local and hosted baseline; fresh clone in path with spaces; home Mac remains unverified | Merged in PR #1; no application cross-device sync implemented |
| PR-01 documentation consolidation | Complete source relocated intact; one master execution plan; roadmap/progress/coordination/briefs; architecture/ADRs; current navigation | Local Markdown links/anchors and exact case checked; source/spec and license byte equality; all 31 roadmap entries retained. Final-head build/CI evidence belongs on PR #1 | Merged in PR #1 |
| PR-02 feasibility | ADRs 0004–0007, official source audit, PR-03 domain constraints | Disposable API typechecks; standard check evidence below/PR | Merged in PR #3 at `c96f4f0cbb54e2397d5c987a80cc2c0cd9ab0630`; no integrations |
| PR-03 core domain | CoreDomain values, read/write contracts, proposals, explicit uncertainty, public-API synthetic tests and compiler boundary checks | Scoped model/compiler evidence below; final-head checks on GitHub PR #4 | Merged in GitHub PR #4 at `a990e05721e75770df98ba01c2bad2bc5aa731a7` |
| Work package 04 permission engine | Trusted policy authority, bound sessions/receipts, resource/field decisions and response filtering | Synthetic policy/compiler evidence below | Merged in GitHub PR #5 at `0cdac4bd5845b2b167a48c00332ef5ddf5080606` |
| Work package 05 native application | Native navigation/menu/Settings, synthetic connection policy previews, bounded in-memory activity | Eight application tests and scoped work-Mac UI inspection below | Merged in GitHub PR #6 at `12b4ebf80816dcd307673a64085d00f88bb20981` |
| Work package 06 Calendar discovery | Explicit opt-in, EventKit metadata actor, local source identity and memory-only selection | Synthetic concurrency/selection tests, adapter mapping/signals, scoped native UI; live TCC/sandbox unverified | Merged in GitHub PR #7 at `ab345134daa94f4a4a195ae709e94d6f3d29c7e2` |
| Work package 07 Calendar reads | Selected bounded events, normalization, trusted field projections and local availability UI | 19 new synthetic tests and native synthetic harness; full gates below/PR; live provider unverified | Merged in GitHub PR #8 at `34c5c55019d805514117cb41c99adc5c67b1ba9a`; milestone A live gate open |
| Work package 08 Google OAuth/Keychain | Independent auth module, browser/loopback/HTTP/Keychain adapters, lifecycle and native setup state | Synthetic protocol/lifecycle and real localhost tests; live activation blocked on setup/signed proof | Merged in GitHub PR #9 at `4d80fabae8b2b3a4482b582a48e974656a02eb3f`; live activation blocked |
| Work package 09 Google destination | Internal owned destination/event client, private authenticated transport, pagination and conditional writes | Synthetic fixtures and session/concurrency tests; full gates recorded below/PR | Merged in GitHub PR #10 at `928732effe0985ed34a386cba4367ffd69bdc43c`; live activation blocked |
| Work package 10 SQLite persistence | Isolated versioned store, bound mappings/fingerprints, pending operations/state/checkpoints | Synthetic real-SQLite migration/restart/failure tests; full evidence below/PR | Merged in GitHub PR #11 at `4a5ad09a22be45b681c46675d756500603a58d8c`; inactive |
| Work package 11 pure planning | Deterministic comparison, privacy projection, conflicts and guarded deletion proposals | Synthetic public-API tests and compiler boundaries; evidence below | Merged in GitHub PR #12 at `567b5a1a644c4b1ccba10eb21687c8d84d5c82cf`; inactive |
| Work package 12 executor | Internal ordered execution, durable IDs, verified results and read-only unknown recovery | Real SQLite/planner/client with synthetic transport; evidence below | Merged in GitHub PR #13 at `1d265050f0e12aa21847b26875e32e12c0d13f4b`; live activation denied |
| Work package 13 recurrence/time | Bounded batch guards, civil horizon, lossless timestamps and content-v2 comparisons | Synthetic provider/planner/store/executor and time-boundary coverage below | Merged in GitHub PR #14 at `554c4f2cc7914ae4b963f30b28cb529c94f1d3fe`; live gates open |
| Work package 14 deletion/recovery | Exact destructive batch approval, verified reconstruction and cooperative writer transfer | Synthetic failure injection; evidence below | Merged in GitHub PR #15 at `69a23b9c7a96b8ffc562400a4b9db7642eaf55d2`; live activation denied |
| Work package 15 background | Internal serialized scheduling, lifecycle hints and explicit login control | Synthetic lifecycle/executor tests and scoped idle sample below | Merged in GitHub PR #16 at `29f447b47948b054bc6266a946232bcc826d6881`; live sync inactive |
| Work package 16 Google onboarding | Native selected-source/privacy/review/status flow, internal trusted orchestration and paused SQLite preferences | Synthetic workflow/state/migration tests and unsigned setup UI inspection; acceptance below | Merged in GitHub PR #17 at `4d1bc9467b9b827e61fbf493004f4d5ae525982a`; signed/live activation and milestone B remain open |
| Work package 17 MCP foundation | Separate bounded synthetic stdio helper, modern/legacy profiles, typed schemas and mock tools | Swift/subprocess and independent official SDK checks below | Merged in [GitHub PR #18](https://github.com/christianzbox/MacHandle/pull/18) at `9bcc8b06113990f2002293981fe3f62b3d218092`; no signed broker or live data |
| Work package 18 MCP Calendar reads | Isolated bound-policy discovery/availability/search/detail adapters and fixed synthetic composition | Scoped tests and SDK/subprocess evidence below | Merged in [GitHub PR #19](https://github.com/christianzbox/MacHandle/pull/19) at `defc08efb19028d4a9a5781c66b31748d217e9eb`; no real external access |
| Work package 19 MCP connection contracts | Channel-bound local review, private saved candidates, revocation/cancellation and content-free audit | Synthetic peer/lifecycle/file tests and protocol checks; evidence below | Merged in [GitHub PR #20](https://github.com/christianzbox/MacHandle/pull/20) at `77c3b797d403a5cfe957ac56d1b23f2c3462bea0`; signed authentication/native pairing remain gated |
| Work package 20 action approval | Exact local Calendar reviews, single-use confirmation, conditional mock dispatch and native sample presentation | Engine/model tests and scoped unsigned UI inspection; evidence below | Merged in [GitHub PR #21](https://github.com/christianzbox/MacHandle/pull/21) at `5dda18451154e0a72b2ecb47df851c8ebb4a306b`; no real source writes |
| Work package 21 Calendar mutations | Gated EventKit adapter, durable dispatch journal and restart containment | 16 new synthetic tests and API compile checks; evidence below | Merged in [GitHub PR #22](https://github.com/christianzbox/MacHandle/pull/22) at `9b5f01ccacd449ae3e1b00e5f29c2672692679d1`; no live write activation |
| Work package 22 Reminders reads | Independent EventKit authorization, native local opt-in/selection/search/details, paired read grants and three synthetic MCP tools | Synthetic tests, API compile, subprocess/SDK and native build checks; evidence below | Merged in [GitHub PR #23](https://github.com/christianzbox/MacHandle/pull/23) at `1e09e40b92dcc9a1f18ab287e535e3f8f0d1c649`; live MCP remains gated |
| Work package 23 Reminder management | Separate observed-state approval, journal, gated provider, native sample and MCP proposal/commit tools | Synthetic behavior and final-head results below/PR | Merged in [GitHub PR #24](https://github.com/christianzbox/MacHandle/pull/24) at `03cdcb34173a4ecacb512fe10286a025efc10d60`; live writer closed |
| Work package 24 Contacts reads | Independent native opt-in, minimal underlying-record reads, field/subset policy and synthetic MCP tools | Synthetic provider/application/adapter/settings and compiler/protocol checks below | Merged in [GitHub PR #25](https://github.com/christianzbox/MacHandle/pull/25) at `472981db82768cc6420c643e90e596f8ab805ccc`; signed/runtime and live MCP gates open |
| Work package 25 Contacts management | Independent observation/approval, dedicated journal, gated public-API writer, native samples and synthetic MCP proposals | Synthetic behavior and exact-head results below/PR | Merged in [GitHub PR #26](https://github.com/christianzbox/MacHandle/pull/26) at `9704899f45b2a03c37e514a206f5b75d7c075122`; live writes closed |
| Work package 26 Notes feasibility | Public-source/dictionary review, capability matrix, ADR-0031 and isolated acceptance protocol | Static evidence only; sandboxed synthetic prototype and all live capabilities deferred with owners/triggers | Merged in [GitHub PR #27](https://github.com/christianzbox/MacHandle/pull/27) at `4450809877cc553bfebc7bfa051ac269884e3865`; no release |
| Work package 27 Notes availability | Shared static native explanation and consistent public capability/privacy guidance; explicit deferral delivered | Source/composition review, synthetic/build checks and scoped native inspection below; no runtime Notes proof | Merged in [GitHub PR #28](https://github.com/christianzbox/MacHandle/pull/28) at `c1012935d701224a46146bbed4a5f8850055e030`; no release |
| Work package 28 Remote readiness | Dated platform/security investigation, private-tunnel candidate, explicit activation deferral, R1–R6 matrix and static native notice | Documentation and synthetic/presentation evidence only; no remote transport/auth or live client proof | Merged in [GitHub PR #29](https://github.com/christianzbox/MacHandle/pull/29) at `52cc55be15f0e325d4e5107f59c88da8b18f4b46`; remote activation deferred |
| Work package 29 Diagnostics/hardening | Live UI-state diagnostics, allowlisted preview/save, recovery navigation and scoped security review | Synthetic privacy tests and scoped native/resource checks; acceptance below | Merged in [GitHub PR #30](https://github.com/christianzbox/MacHandle/pull/30) at `4d47859f390d0fcf7f8e755d173217e8caa47476`; no certification or release |
| Work package 30 Release preparation | Clean-source development packaging, closed bundle profile, manifest/checksums, distribution refusal and account/release policy | Nine synthetic packaging tests; integration and gate evidence below/PR | In review; production signing/notary/publication deferred |
| Work package 31 Plugin distribution | Conditional planned decision gate | No platform approval or live compatibility | Not merged; no release |

## Work package 30 evidence — Release engineering readiness

GitHub PR #30 was verified merged at `4d47859f390d0fcf7f8e755d173217e8caa47476` on
2026-10-29 12:07:15 America/Detroit (16:07:15 UTC). Both hosted checks passed on feature head
`898848856f2ea577e5e108444f794b6ee4cf7ed0` in
[Foundation CI run 40904907642](https://github.com/christianzbox/MacHandle/actions/runs/40904907642).
Created `codex/release-engineering-readiness` from fetched main after user authorization; Work Mac
is the only writer and home setup remains unverified.

[ADR-0034](../architecture/decisions/0034-release-engineering-readiness.md) implements a safe local
packaging route: fresh committed snapshot, signing disabled, no app launch and exactly the reviewed
bundle files. Integrity verification rejects altered metadata, extra/private files, links and unsafe
archive entries; valid rehearsal output still fails the distribution gate. Nine synthetic tests
passed; hardlink metadata is simulated where the OS prohibits creating app-bundle hardlinks.

The [account checklist](../development/account-release-checklist.md),
[release runbook/gates](../development/release-engineering.md) and revised installation/update/
rollback/security/privacy guidance distinguish unsigned local artifacts from signed distribution.
Official Apple enrollment/Developer ID/notary sources were checked 2026-10-29. No account, credential,
permission, signing identity, production bundle ID, app entitlement, provider code or CI authority
changed. No tag/release/upload or personal iCloud access. Production signing/notary/Gatekeeper,
provider/IPC/Keychain, full accessibility and compatibility remain owned P1–P5 gates; Notes/remote
retain G1–G6/R1–R6. [Acceptance](prs/pr-30.md#implementation-and-acceptance) and the PR record
integration/final-head evidence. Package 31's conditional brief is prepared, not started.

## Work package 29 evidence — Diagnostics and security hardening

GitHub PR #29 was verified merged at `52cc55be15f0e325d4e5107f59c88da8b18f4b46` on
2026-10-29 11:31:49 America/Detroit (15:31:49 UTC). Both hosted checks passed on final feature
`3efcc898b9d5affaa508c2e4457b1136becd7042` in
[Foundation CI run 40901450931](https://github.com/christianzbox/MacHandle/actions/runs/40901450931).
Created `codex/diagnostics-security-hardening` from fetched main after explicit user authorization;
Work Mac is the only writer and home setup remains unverified.

[ADR-0033](../architecture/decisions/0033-diagnostics-support-report.md) and the
[scoped audit](../development/diagnostics-security-audit.md) record fixed status/history/retry copy,
closed-schema report capture and user-reviewed local export. The new entitlement is user-selected
file read/write only; no new provider/network/automation capability, dependency or live composition.
Three synthetic tests cover private-data/raw-error exclusion, provider noninterference, frozen
snapshots, opt-in versus permission, disabled precedence and bounded phase/failure output.

Native unsigned checks confirmed default services off, readable diagnostics/report AX labels and
layout, Command-4 navigation, Return opening the save panel and Escape cancelling it. The first
sheet test caught a blank presentation, fixed with item-bound immutable state and verified after
relaunch. A task-owned temporary export exactly matched the 423-byte preview. No live service,
iCloud profile, permission, Keychain or private database was accessed. Acceptance measurements and
final-head local/hosted evidence belong in [the brief](prs/pr-29.md#implementation-and-acceptance)
and review PR. The package 30 brief is planned only. Signed sandbox/provider end-to-end, live audit,
full accessibility and sustained load remain owned gates; Notes and remote activation stay deferred.


Scoped resource sample: six `ps` observations at five-second intervals over 25 seconds with the
report preview idle and all services off recorded 0.0% CPU and 130,784 KiB RSS throughout. This is
one unsigned work-Mac snapshot, not a load/leak/energy benchmark or a provider-performance claim.
App quit and process exit were verified.

Staged gates passed on this implementation: environment 0.23 s, validate 46.68 s, secret scan
1.55 s. Validation includes 445 Swift tests, 23 Python checks, 51 expected compiler rejections,
formatting, SwiftPM build, Debug/Release Xcode builds and analyzer, indexed privacy and diff checks.
All 1,268 documentation links/anchors and 31 roadmap anchors passed; protected files remain equal
to the merged base, with exactly the reviewed user-selected-file entitlement added. Final-head
repeats after handoff edits and hosted results are recorded in the PR. This is not live acceptance.

Implementation checkpoint `91d32b1291932e91c754f0178396f1041613dc30` is pushed; exact final-head
local/hosted evidence belongs in [GitHub PR #30](https://github.com/christianzbox/MacHandle/pull/30).

## Work package 28 evidence — Remote MCP readiness decision

GitHub PR #28 was verified merged at `c1012935d701224a46146bbed4a5f8850055e030` on
2026-10-29 11:16:24 America/Detroit (15:16:24 UTC). Both hosted checks passed on final feature
`7de76b304fcf47e0730221cacd651492fde4239e` in
[Foundation CI run 40898547813](https://github.com/christianzbox/MacHandle/actions/runs/40898547813).
Created `codex/remote-mcp-readiness` from fetched main after explicit user authorization.
Work Mac is the only writer; home setup remains unverified.

[ADR-0032](../architecture/decisions/0032-remote-mcp-readiness.md), the
[compatibility/activation matrix](../development/remote-mcp.md) and
[acceptance](prs/pr-28.md#implementation-and-acceptance) record current official MCP/OpenAI evidence
and the explicit deferral route. A private authenticated tunnel is a future experiment candidate;
no remote auth service/configuration, signed broker or actual client proof exists. R1–R6 retain the
engineering/maintainer owners and isolated account/setup triggers. The native Connections notice
states remote access is unavailable and future awake/online/running requirements. Local functionality
remains independent. Public privacy/account guidance agrees; package 29's brief is planned only.

No listener, tunnel, OAuth server, token verifier, new module, package dependency, entitlement,
credential or provider behavior is introduced. Existing synthetic stdio is unchanged; synthetic
identity never becomes remote authority. Notes remains deferred. Staged gates passed: environment
0.35 s, validation 62.90 s, secret scan 1.67 s; 442 Swift tests, 23 Python checks, 51 expected compiler
rejections, formatting, SwiftPM build, Debug/Release Xcode builds and analyzer. All 1,233 local
documentation links/anchors and 31 roadmap anchors passed; protected files and entitlements unchanged.
The diff contains one static presentation change and 18 Markdown files; composition, provider/transport
code, tests, package and CI are unchanged. Xcode emitted only its existing optional AppIntents warning.

Scoped native inspection confirmed a readable remote-unavailable notice with no activation control,
Google Connect disabled and default discovery/sample connections off. No service was enabled or
permission prompt shown; app quit and process exit verified. This is unsigned presentation/synthetic
evidence, not remote authentication, actual client, full accessibility or signed/provider acceptance.
Exact final-head repeats and hosted results belong in the review PR. No personal iCloud data, account
setting, remote client configuration or MCP endpoint was used or changed. Implementation checkpoint
`7a997cbfcebaad0e9414a8395e054a04bff85b7a` is pushed; exact final-head evidence belongs in
[GitHub PR #29](https://github.com/christianzbox/MacHandle/pull/29).

## Work package 27 evidence — Notes experimental availability

GitHub PR #27 was verified merged at `4450809877cc553bfebc7bfa051ac269884e3865` on
2026-10-29 11:02:10 America/Detroit (15:02:10 UTC). Both hosted checks passed on final feature
`1e9d9f9afca009ae3c643005330c3ea9951533e6` in
[Foundation CI run 40896276270](https://github.com/christianzbox/MacHandle/actions/runs/40896276270).
Created `codex/notes-experimental-availability` from fetched main after explicit user authorization.
Work Mac is the only writer; home setup remains unverified.

[Acceptance](prs/pr-27.md#implementation-and-acceptance) and the
[ADR follow-up](../architecture/decisions/0031-notes-feasibility.md#work-package-27-availability-follow-up)
cover shared informational Notes status in Overview/Diagnostics, reading/editing limitations and
no permission request, with matching README/privacy/setup guidance. Adjacent Diagnostics labels now
include existing Reminders/Contacts opt-in reads. No Notes state, provider, tools, task, callback,
activation control, entitlement or permission string was added; existing live gates remain unchanged.
G1–G6 and their engineering/maintainer owners remain deferred, not satisfied. Package 28's brief is
prepared for a separate remote security/platform investigation; no verdict or implementation yet.

Source/composition review confirms the Notes view contains only presentation and default-disabled
provider refreshes cannot start discovery. Staged gates passed: environment 0.41 s, validation
75.37 s, secret scan 2.45 s; 442 Swift tests, 23 Python checks and 51 expected compiler rejections,
formatter, SwiftPM build, Debug/Release Xcode builds and analyzer. All 1,191 local documentation
links/anchors, 31 roadmap anchors and protected-file/entitlement checks passed. The diff contains
15 Markdown files and only one presentation source change; composition, providers, package and CI
are unchanged. Xcode emitted only its existing optional AppIntents metadata warning.

Native inspection of the built Debug app confirmed the matching Notes explanation and readable
layout in Overview/Diagnostics, with Calendar/Reminders/Contacts discovery off and external previews
disabled. No service was enabled or permission prompt presented. The app was quit and process exit
verified. This is scoped unsigned presentation evidence, not maintained UI automation, full
accessibility coverage or signed/live provider acceptance. Exact final-head local repeats and hosted
results belong in the review PR. No personal iCloud data, permission changes or live Notes operations
were used for development. Implementation checkpoint `1e4b18130bb67ed8f1c8272830b70514365a3405`
is pushed; final-head evidence belongs in [GitHub PR #28](https://github.com/christianzbox/MacHandle/pull/28).

## Work package 26 evidence — Notes feasibility decision

GitHub PR #26 was verified merged at `9704899f45b2a03c37e514a206f5b75d7c075122` on
2026-10-29 10:44:40 America/Detroit (14:44:40 UTC). Both hosted checks passed on final feature
`de7b2e9bf6256ff71cd877b06c6262317dbebb26` in
[Foundation CI run 40893005054](https://github.com/christianzbox/MacHandle/actions/runs/40893005054).
Created `codex/notes-feasibility-review` from fetched main after user direction to continue building
with personal testing later. Work Mac is the only writer; home setup remains unverified.

[ADR-0031](../architecture/decisions/0031-notes-feasibility.md), the
[capability matrix](../development/notes-feasibility.md#capability-matrix) and
[acceptance](prs/pr-26.md#implementation-and-acceptance) distinguish declared terminology from
runtime proof. Inspected official public documentation and installed Notes 4.13 (3195.42.3) and
inherited Cocoa Standard dictionaries on macOS 27.2 (26B123). Versions/hashes and a reproducible
metadata-only inspection are recorded. No Apple events, Notes launch, shortcut inventory/execution,
private database, personal data, account setting or permission prompt was involved.

Decision: defer all live Notes activation; this does not establish permanent infeasibility. The
required sandboxed synthetic prototype remains unperformed, engineering-owned pending maintainer
setup/authorization of an isolated fixture environment and signing identity. G1–G6 retain consent,
selection, identity, fidelity, concurrency and distribution gates. Package 27 is prepared for explicit
deferral/availability documentation only. Existing app/provider/MCP behavior and entitlements are
unchanged. Repository test results cannot prove Notes support. Staged local gates passed: environment 0.28 s, validation 37.23 s, secret scan 1.57 s;
442 Swift tests, 23 Python checks and 51 negative compiler probes, formatter, SwiftPM build,
Debug/Release Xcode builds and analyzer. All 1,161 local documentation links/anchors, 31 roadmap
anchors, immutable source/spec/license/toolchain/CI checks and unchanged entitlements passed. The
published static reproduction matched both hashes and the documented command/group inventory.
The diff contains only 14 Markdown files. Implementation checkpoint
`90586eca5f698fd24b01578a2178d170ac1f26b9` is pushed. Exact final SHA/repeat checks and hosted
results belong in [GitHub PR #27](https://github.com/christianzbox/MacHandle/pull/27).

## Work package 25 evidence — Approved Contacts management

GitHub PR #25 was verified merged at `472981db82768cc6420c643e90e596f8ab805ccc` on
2026-10-29 10:19:39 America/Detroit (14:19:39 UTC). Both hosted checks passed on final feature
`01e24297dfde4ce28b840ac1c2e5982ff14ea5d8` in
[Foundation CI run 40888241127](https://github.com/christianzbox/MacHandle/actions/runs/40888241127).
Created `codex/authorized-contacts-management` from fetched main after explicit user authorization.
Work Mac remains the only writer; home setup is unverified.

[ADR-0030](../architecture/decisions/0030-contacts-management.md) and
[acceptance](prs/pr-25.md#implementation-and-acceptance) cover three independently approved operations,
scoped observation without execution authority, exact underlying targets and current permissions,
whole-record deletion acknowledgement plus DELETE phrase, native field preservation and separate
durable intent/receipt containment. Saved read candidates never gain writes. MCP proposals have no
wire approval channel; the helper cannot execute them. Commit tool hints accurately flag mutation,
destructive potential and non-idempotency; policy does not trust those hints.

The first full staged gates passed: environment 0.20 s, validation 94.13 s, secret scan 1.89 s.
Validation included 442 Swift tests, 23 Python checks and 51 negative compiler probes, formatter,
SwiftPM build, Debug/Release Xcode builds and analyzer. All three official SDK profiles passed;
1,131 local documentation links/anchors and unchanged specification/license/toolchain/CI/entitlements
passed. Native sample update before/after fields, cancellation and deletion controls were inspected:
checkbox alone kept confirmation disabled; checkbox plus DELETE enabled it. Both reviews were
cancelled, app quit, and no OS prompt or real Contacts access occurred. A final copy-only clarification
removes internal runtime wording from the sample scope. Implementation checkpoint `6bffbce60a6bf99eb43a461a33adab7f64e428f1`
passed all staged gates again: environment 0.47 s, validation 68.21 s, scan 2.26 s. Final-head gates
are repeated in the PR.
Xcode emitted only the existing optional AppIntents metadata extraction warning. Final-head
repeats and hosted results belong in the linked PR. No real contact, OS prompt, write, production store,
client configuration, signing identity or entitlement change is used. The public native API remains
last-writer-wins; signed peer/native pairing, writable container continuity, linked effects, provider
conflict acceptance, minimum OS/home Mac and unknown recovery remain owned engineering gates. Postal
wire/fidelity limits and restricted notes have explicit triggers in the ADR. Package 26 is planned
Notes feasibility only, with no feasibility verdict or implementation implied.

## Work package 24 evidence — Contacts discovery and reads

GitHub PR #24 was verified merged at `03cdcb34173a4ecacb512fe10286a025efc10d60` on
2026-10-29 09:17:09 America/Detroit (13:17:09 UTC). Both hosted checks passed on final feature
`74401cd223f0f171dd664005fcdfb9a86a944714` in
[Foundation CI run 40772811756](https://github.com/christianzbox/MacHandle/actions/runs/40772811756).
Created `codex/contacts-read-operations` from fetched main after user authorization; Work Mac remains
the only writer and home setup is unverified.

[ADR-0029](../architecture/decisions/0029-contacts-reads.md) and
[acceptance](prs/pr-24.md#implementation-and-acceptance) cover independent native opt-in, explicit
field/record selection, underlying identities, minimal key fetches, membership rechecks and projection
before search. Settings v3 migrates without expanding older grants. The helper adds three synthetic
read tools with temporary handles and current-authority checks; no live Contacts provider is linked.
The app adds only the public address-book entitlement and usage description needed for opt-in.

Implementation checkpoint `f5608cbee5beb983adf7da9f8e043bd2dfd9fb39` passed all three staged gates:
environment 0.34 s, validation 45.13 s and secret scan 1.50 s. Validation includes 411 Swift tests, 23 Python checks (10 protocol plus 13 preflight/privacy),
44 negative compiler probes, Debug build/analyze and Release build. All three independent official
SDK profiles passed. Native Overview and the disabled Contacts screen/layout were inspected without
pressing Enable; no prompt appeared and the app was quit. Xcode emitted only the existing optional
AppIntents metadata warning. Documentation links/anchors and the exact entitlement addition passed.
Final-head repeats and hosted CI are recorded separately in the linked PR. No personal contact,
permission prompt, real write, client setup, signing identity or production store is used. Runtime
TCC/sandbox/minimum-OS/linked-record behavior and signed peer/native pairing remain engineering-owned
gates. Restricted Contacts notes, unified display and persistent identity continuity have explicit
owners and revisit triggers in the ADR. Package 25 is planned only; Notes.app remains experimental.

## Work package 23 evidence — Approved Reminders management

GitHub PR #23 was verified merged at `1e09e40b92dcc9a1f18ab287e535e3f8f0d1c649` on
2026-10-28 17:22:36 America/Detroit (21:22:36 UTC). Both hosted jobs passed on final feature
`03befb32f8d84b43b878682e836aa04cce5f869d` in
[Foundation CI run 40769659556](https://github.com/christianzbox/MacHandle/actions/runs/40769659556).
Created `codex/authorized-reminders-management` from fetched main after explicit authorization;
Work Mac is the only writer; home setup remains unverified.

[ADR-0028](../architecture/decisions/0028-reminders-management.md) and
[acceptance](prs/pr-23.md#implementation-and-acceptance) cover six independent approved operations,
scoped observation before binding a mutation precondition, short-lived single-use native confirmation,
current authority/target checks, field projection, independent complete/uncomplete rights and Google
denial. The dedicated journal persists intent before dispatch, rejects Calendar stores and blocks
pending/unknown operations across restart. EventKit code compiles behind a closed live factory.
Native Connections offers fixed sample reviews; two additional MCP tools propose/commit against a
separate sample connection with no wire approval. The standalone helper cannot execute its proposals.

Initial staged gates passed: environment 0.26 s, validation 57.46 s, secret scan 1.48 s;
388 Swift tests, 23 Python checks and 40 negative compiler probes. Official SDK 1.26.0 legacy and
2.4.0 pinned/auto checks passed. 1073 local documentation links and all 31 roadmap anchors passed.
Unsigned work-Mac UI inspection verified six sample actions, exact uncomplete review/result,
delete acknowledgement gating and cancellation; the app quit afterward. A clipped due-date button
was corrected by widening adaptive columns and reinspected successfully. The final implementation
source tree committed as `2e6ddaa2a5001f58f3a1cad522914cb79bfdf45c` passed all three gates again:
environment 0.26 s, validation 50.81 s, secret scan 1.55 s. [GitHub PR #24](https://github.com/christianzbox/MacHandle/pull/24) is open for review.
The handoff-only commit receives fresh gates; its exact SHA/local/hosted outcomes belong in the PR. Tests use synthetic data and temporary private SQLite only.
No actual Reminder object, personal list, permission prompt, signed identity, client setup or
production store is used. Broader recurrence/alarm/list-move support is explicitly deferred with
engineering ownership and isolated-fixture revisit triggers. Live conflict/identity/native bridge,
signed TCC/sandbox/minimum-OS and unknown-result recovery gates remain closed. Contacts package 24
is prepared only; Notes remains experimental.

## Work package 22 evidence — Reminders authorization and reads

GitHub PR #22 was verified merged at `9b5f01ccacd449ae3e1b00e5f29c2672692679d1` on
2026-10-28 16:53:46 America/Detroit (20:53:46 UTC). Final feature SHA
`af5d1ed9ab9379cc849b839fbce28c7432b13766` passed both hosted jobs in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40765941872).
Created `codex/reminders-read-operations` from fetched main after explicit authorization;
Work Mac is the only writer.

[ADR-0027](../architecture/decisions/0027-reminders-reads.md) and the
[acceptance ledger](prs/pr-22.md#implementation-and-acceptance) record independent Reminders
contracts/provider, native opt-in with no default selection, scoped local search/details and explicit
notes access. Async EventKit fetches have cancellation completion, a deadline, active-request limits
and post-read OS/inventory/change checks. Due components retain civil/floating/zone distinctions;
completion and recurrence presence are separate fields. Provider revision remains unknown.

Read-only saved Reminder grants use settings v2; v1 gains none. Reminders-only pairing no longer
requires Calendar access. MCPRemindersAdapter requires a paired lease and current authority; list,
search and exact-detail tools use projection before matching and opaque, bounded, expiring handles.
Final output rechecks revocation/expiry. The helper remains synthetic-only with eleven tools.
Calendar mutation activation stays closed and Google obtains no Reminder access.

Twenty-three new Swift tests cover provider normalization/cancellation, native opt-in and late-result
suppression, independent grant migration, projection, foreign/expired handles, partial absence,
revocation/cancellation and queued output. Existing tests also cover Reminder policy behavior.
Focused tests passed after correcting Calendar-only pairing assumptions, preserving empty-grant
connections without authority, and updating protocol inventory expectations to eleven tools.
Full validation passed with 358 Swift tests, 23 Python checks and 35 negative compiler probes.
Official SDK 1.26.0 legacy and 2.4.0 pinned/auto checks passed. Unsigned native inspection verified
the disabled Reminders screen, explicit Enable and disabled Refresh, without invoking a permission
request; the preview was quit. Populated/runtime/signed/accessibility acceptance is not claimed.
Debug/Release usage descriptions were verified. Implementation checkpoint
`9eb43fd23cfbd51e8e77af011185b275fbd49571` is pushed in [GitHub PR #23](https://github.com/christianzbox/MacHandle/pull/23).
Its staged tree passed all three gates: environment 0.33 s, validation 48.69 s and secret scan
1.78 s, using pinned Xcode 27.1 (27A9275), Swift 6.4 and SDK 27.0. Strict formatting, package
build/tests, unsigned Debug/Release builds, analyzer, indexed privacy and history/index secret scans
passed. Initial formatter/unnecessary-await findings were corrected before the passing run. No
scanner proves content absence. Documentation checks passed 1041 local links and 31 roadmap anchors;
specification, LICENSE, toolchain, CI and entitlements are preserved. The PR records exact final-head
reruns and hosted CI separately; hosted checks were pending at this documentation checkpoint.

No actual permission, personal data, account or installed client configuration was used. Native
permission/read behavior, signed sandbox/minimum-OS, actual clients and large-list behavior remain
engineering/maintainer-owned acceptance after approved identity and isolated synthetic-list setup.
EventKit may allocate its full native result array; processing is capped at 1000 and coverage marked
partial. Recurrence rules/alarms and all Reminder writes remain package 23 work, whose brief is
planning only. Notes still needs package 26's feasibility gate.

## Work package 21 evidence — journaled Calendar mutations

GitHub PR #21 was verified merged at `5dda18451154e0a72b2ecb47df851c8ebb4a306b` on
2026-10-28 15:57:47 America/Detroit (19:57:47 UTC). Final feature head
`53abfe9c3b46e3146f596689775027430388c5f6` passed both hosted jobs in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40756314388).
Created `codex/authorized-calendar-mutations` from fetched main after user authorization;
Work Mac remains the sole writer.

[ADR-0026](../architecture/decisions/0026-calendar-mutation-journal.md) and the
[acceptance ledger](prs/pr-21.md#implementation-and-acceptance) record the EventKit adapter,
trusted authority checks after durable intent, separate private SQLite journal, matching receipts,
replay denial and pending/unknown containment across restart. Production factory always denies;
app/helper/Google paths acquire no writer. EventKit save is not atomic compare-and-swap and may
recreate a concurrently deleted item. Standalone-only candidate scope explicitly rejects unsupported
recurrence/meeting/time cases. Existing live reads still expose unknown mutation preconditions.

Twelve new adapter/scope tests and four journal tests passed using synthetic backends/private temp
stores. They exercise create/update/delete, intent ordering, replay, restart, uncertain/mismatched
receipts, pre/postacceptance cancellation, revocation after intent, concurrency, foreign targets,
recurrence rejection, DST/precision and SQLite identity/schema/file/transaction safety. No test
initializes EventKit or accesses actual calendars. Implementation checkpoint `e54a0c9992bf7c5b30870b35d3432b75ab397140` is pushed in [GitHub PR #22](https://github.com/christianzbox/MacHandle/pull/22).
Its staged tree passed all three gates: environment 0.20 s, validation 48.48 s and secret scan
1.51 s, with pinned Xcode 27.1 (27A9275), Swift 6.4 and SDK 27.0. This includes 335 Swift tests,
23 Python checks, 33 negative compiler probes, strict formatting, package builds, unsigned native
Debug/Release builds, analyzer and indexed privacy checks. Initial compiler-import and formatter
findings were corrected before the passing run. No scanner proves content absence. Official SDK
1.26.0 legacy and 2.4.0 pinned/auto smoke checks passed. Documentation checks passed 1010 local
links and all 31 roadmap anchors; specification, LICENSE, toolchain, CI and entitlements were
preserved. The PR records the exact final handoff SHA, repeated gates and hosted CI independently;
hosted checks were pending at this documentation checkpoint.

Engineering/maintainer retain signed broker/native grants/review/outcome UI, scoped live candidate
reads, recovery/retention procedure and isolated EventKit conflict/recurrence/time experiments before
activation. No identity or authorized synthetic calendar is configured. Native preview stays synthetic;
no permission, content, credential, account or client configuration was used. See
[developer procedure](../development/calendar-mutations.md) for exact acceptance limits. Package 22
has a planning brief only; no Reminders/Notes capability is claimed by this package.

## Work package 20 evidence — action proposal and approval

GitHub PR #20 was verified merged at `77c3b797d403a5cfe957ac56d1b23f2c3462bea0`
on 2026-10-28 15:26:07 America/Detroit (19:26:07 UTC). Its final feature head
`6a929697028ad0bd32431a4146c82e0934e0ff72` passed both hosted jobs in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40753524993).
Created `codex/action-proposal-approval` from fetched main after user authorization.
Work Mac remains the sole writer.

[ADR-0025](../architecture/decisions/0025-action-proposal-approval.md) and the
[acceptance ledger](prs/pr-20.md#implementation-and-acceptance) record exact retained
Calendar mutations, field-scoped literal diffs, expiring local confirmation and serialized
single-use dispatch. Policy/channel/OS and current provider state are rechecked; the mock
conditionally compares and mutates without suspension. Unknown receipts block further
writes. Native Connections offers separate synthetic create/update/delete review and cancel,
with deletion acknowledgement and stale UI-ID rejection. No live writer or MCP grant is added.

Twenty new engine tests plus two UI-model tests bring totals to 319 Swift + 23 Python checks
and 30 negative compiler probes. Focused tests passed. Unsigned work-Mac inspection verified
sample create/update/delete completion, cancel, deletion confirmation gating, literal diff
layout and corrected accessibility labels for each before/after row. The preview was quit;
no real permission, content, account or installed client configuration was used.
Implementation checkpoint `8026c86285b7e3358a3de27a621825cf250437e1` is pushed in [GitHub PR #21](https://github.com/christianzbox/MacHandle/pull/21).
Its staged tree passed `bash Scripts/check_environment.sh` (0.20 s), `bash Scripts/validate.sh`
(43.91 s) and `bash Scripts/scan_secrets.sh` (1.56 s), using pinned Xcode 27.1 (27A9275),
Swift 6.4 and SDK 27.0. This includes formatting, package build/tests, Debug/Release builds,
analysis and privacy/history/index scans. Initial test actor-access and formatter findings
were corrected before the passing run. No scanner proves data absence. Official SDK 1.26.0
legacy and client 2.4.0 modern/auto checks passed. Documentation checks passed 977 local links
and 31 roadmap anchors; canonical specification, LICENSE, toolchain, CI and entitlements were
preserved. The PR records final pushed handoff SHA, repeated local gates and hosted outcomes
independently; hosted CI was pending at this documentation checkpoint.

Signed peer/current OS/native live pairing remain engineering/maintainer-owned gates after
approved identity setup. Package 21 additionally owns explicit write grants, actual provider
version/recurrence/conflict behavior, durable pre-dispatch journal and unknown/restart recovery,
and native live-review integration before real source writes. Memory-only approval/audit does
not prove crash-safe idempotency, full VoiceOver, minimum-OS or milestone C acceptance.
Google remains independently gated. [Package 21](prs/pr-21.md) is planning only; stop for review.

## Work package 19 evidence — MCP connection contracts

GitHub PR #19 was verified merged at `defc08efb19028d4a9a5781c66b31748d217e9eb`
on 2026-10-28 15:03:57 America/Detroit (19:03:57 UTC). Its final feature head
`b8fc2f4f576eac310ccefdf374ce43b7dd71b928` passed both hosted jobs in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40744364814).
Created `codex/mcp-connection-identity` from fetched main after user authorization.
Work Mac remains the sole writer.

[ADR-0024](../architecture/decisions/0024-mcp-connection-identity.md) and the
[acceptance ledger](prs/pr-19.md#implementation-and-acceptance) record channel-bound local
review, saved disabled candidates, explicit field/resource grants, revocation/cancellation,
OS invalidation and bounded content-free audit. Failed settings writes close admission;
restart cannot resurrect access. The stdio fixture composes this flow with synthetic peers
and memory settings only. Private file storage is explicit and unconnected to the app.

Eighteen new Swift tests bring totals to 297 Swift + 23 Python checks and 26 negative
compiler probes. Implementation checkpoint `a337d39e47d9d3d211a4e40fc425b47974097746` is pushed in
[GitHub PR #20](https://github.com/christianzbox/MacHandle/pull/20). Its staged tree passed `bash Scripts/check_environment.sh` (0.20 s),
`bash Scripts/validate.sh` (34.62 s) and `bash Scripts/scan_secrets.sh` (1.53 s), using
pinned Xcode 27.1 (27A9275), Swift 6.4 and SDK 27.0. This includes formatting, package
build/tests, Xcode Debug/Release builds/analysis and indexed privacy/history scans. An initial
long-comment lint issue was corrected before the passing run. No scanner proves data absence.
Official SDK 1.26.0 legacy and client 2.4.0 modern/auto checks passed, exercising all eight
synthetic tools and schemas through the connection controller. Documentation checks passed
937 local links and 31 roadmap anchors; canonical specification, LICENSE, toolchain, CI and
entitlements were preserved. The PR records final pushed handoff SHA, repeated gates and
hosted outcomes independently; hosted CI was pending at this documentation checkpoint.

Signed mutual peer verification, native pairing UI, app/container/OS/transport integration,
minimum/current OS and actual desktop-client acceptance remain engineering/maintainer-owned
follow-ups after approved identity setup, before personal-data activation. No real account,
content, credentials, permissions or installed client configuration was used. No live
authentication, release or completed milestone C is claimed. Google remains independently
gated. [Package 20](prs/pr-20.md) is planning only; stop for review.

## Work package 18 evidence — MCP Calendar reads

GitHub PR #18 was verified merged at `9bcc8b06113990f2002293981fe3f62b3d218092`
on 2026-10-28 14:02:12 America/Detroit (18:02:12 UTC). Its final feature head
`48b0f5db6be1e5963258b95af0fd842feb5cd54a` passed both hosted jobs in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40740366415).
Created `codex/mcp-calendar-reads` from fetched main after the user's authorization.
Work Mac remains the sole writer.

[ADR-0023](../architecture/decisions/0023-mcp-calendar-reads.md) and the
[acceptance map](prs/pr-18.md#implementation-and-acceptance) record strict discovery,
availability, title search and refetched details through bound policy sessions. Current
OS checks, per-resource/operation/field decisions, projection before matching and delivery
revalidation gate every result. Opaque handles, explicit uncertainty, civil/all-day time,
bounded output/registry and fixed diagnostics prevent raw provider identity/content leakage.
The executable still accepts only `--synthetic`; no EventKit/app/Google/credential/store
or live broker dependency is added. Source calendars cannot be mutated.

Seventeen new Swift tests (15 adapter, two protocol) bring the suite to 279. One added
subprocess case covers reads/privacy in both profiles, bringing Python checks to 23 and
negative compiler probes to 22. Focused Swift, all ten subprocess cases and the independent
official TypeScript SDK 1.26.0 / client 2.4.0 pinned-modern/auto checks passed. The SDKs
exercise all four reads and validate output schemas. Synthetic coverage includes denied,
stale/revoked and cancelled reads, hidden/missing title search, resource/field projection,
foreign/expired/full handle registries, all-day/out-of-window events, duplicate/unknown
identity, incomplete results and oversized responses. Implementation checkpoint
`b9286ca29dfb61d0b7f3624be52c0619872f5054` is pushed in [GitHub PR #19](https://github.com/christianzbox/MacHandle/pull/19). Its staged tree passed
`bash Scripts/check_environment.sh` (0.20 s), `bash Scripts/validate.sh` (25.80 s) and
`bash Scripts/scan_secrets.sh` (1.36 s), using pinned Xcode 27.1 (27A9275), Swift 6.4 and
SDK 27.0. Validation includes formatting, SwiftPM build/tests, Xcode Debug/Release builds
and analysis, preflight/privacy and history/index scans. Documentation checks passed 897
local links and 31 roadmap anchors; canonical spec, LICENSE, toolchain, entitlements and CI
workflow were preserved. No scanner proves data absence. The PR records the final pushed
documentation handoff SHA, repeated gates and hosted outcomes independently; hosted CI was
not yet complete at this documentation checkpoint.

No approved signing identity, real account, content, OS permission, personal client
configuration, app embedding or remote listener was used. Engineering/maintainer retain
signed broker/peer/sandbox/minimum-OS/actual-client acceptance after identity setup, and
package 19 authentication, persistence, revocation and current OS observation integration.
Only fixed immediate fixtures ship; future provider composition needs cancellable deadlines.
Google live activation stays separately gated. Package 19's brief is planning only; stop
for review without merging, publishing or starting that work.

## Work package 17 evidence — MCP server foundation

GitHub PR #17 was verified merged at `4d1bc9467b9b827e61fbf493004f4d5ae525982a`
on 2026-10-28 13:26:41 America/Detroit (17:26:41 UTC). Its final feature head
`294b8fb7f36d748a614c433fa0abe2732bb39ce3` passed both hosted jobs in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40731435543).
Created `codex/mcp-server-foundation` from fetched main after explicit authorization.
Work Mac remains the sole writer.

[ADR-0022](../architecture/decisions/0022-mcp-server-foundation.md) and the
[acceptance map](prs/pr-17.md#implementation-and-acceptance) describe a separate
synthetic-only executable, per-request modern metadata/legacy handshake, typed registry,
structured errors, bounded parsing/framing/concurrency, cancellation and process shutdown.
No provider, credential, permission, Google or app dependency is added to MCPServer.
Existing CI invokes the expanded validation script, including real subprocess tests.

Thirteen new Swift tests bring totals to 262 Swift + 22 Python checks (13 existing and
nine stdio subprocess checks), with twenty negative compiler probes. Implementation
checkpoint `0759cb9345c98dc4d7c8e9f138c49f27c0068fe5` is pushed in
[GitHub PR #18](https://github.com/christianzbox/MacHandle/pull/18). Its staged tree passed
`bash Scripts/check_environment.sh` (0.20 s), `bash Scripts/validate.sh` (29.42 s) and
`bash Scripts/scan_secrets.sh` (1.46 s), using pinned Xcode 27.1 (27A9275), Swift 6.4 and
SDK 27.0. This includes formatting, SwiftPM build/tests, Xcode Debug/Release builds and
analysis, preflight/privacy and history/index scans. Documentation checks passed 857 local
links and 31 roadmap anchors; specification, LICENSE, toolchain, entitlements and CI
workflow were preserved. No scanner proves data absence. The PR records the final pushed
documentation handoff SHA, repeated gates and hosted outcomes independently; hosted CI
was queued/in progress at this documentation checkpoint. Independent official SDK checks passed
with TypeScript SDK 1.26.0 (legacy) and client 2.4.0 (pinned modern and auto negotiation),
using Node 22.14.0 and disposable dependencies outside Git. SDK validation caught required
cache metadata and local stream socket-pair support; fixes precede passing checks.
The durable smoke script and commands are in [developer checks](../development/mcp-foundation.md).

Signed app/helper broker reachability and mutual peer verification remain an owned
engineering/maintainer follow-up after approved development identity setup, before any
personal-data activation. No production signing identity was supplied or used; no signed
IPC, minimum-OS or actual Codex/Claude desktop configuration is claimed. No app registration,
OS permission, real account/content, credentials, client settings or remote listener was
used. Google's separate live-activation ledger remains open. Package 18's focused brief
is preparation only; stop for review without merging or starting it.

## Work package 16 evidence — Google onboarding and preferences

GitHub PR #16 was verified merged at `29f447b47948b054bc6266a946232bcc826d6881`
on 2026-10-28 11:44:47 America/Detroit (15:44:47 UTC). Its final feature head
`13deb162ee050aa1cca346cce0ab91d4f3370507` passed both hosted jobs in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40717817350).
Created `codex/google-sync-onboarding` from fetched main after explicit authorization.
Work Mac remains the sole writer.

[ADR-0021](../architecture/decisions/0021-google-sync-onboarding.md) and the
[acceptance map](prs/pr-16.md#implementation-and-acceptance) describe the native Google
flow, trusted local contracts, retained single-use/expiring plans, field clearing,
full deletion approval, cancellation/drain and bound schema-v3 candidate preferences.
The scheduler handoff preserves intervening source signals without repeating the initial
run immediately. The existing independent authorization and recovery checks remain.

Eighteen added Swift tests bring totals to 249 Swift + 13 Python and eighteen negative
compiler probes. Implementation checkpoint
`7a31d4d01febba0191843f0fce149f8c01546bdd` passed all three staged gates: environment
0.20s, full validation 27.74s and pinned history/index secret scan 1.55s.
Validation includes formatting, warnings-as-errors, all tests/probes, universal unsigned
Debug/Release builds, analysis and indexed privacy/whitespace checks. Supplemental checks
verified 821 documentation links and all 31 roadmap anchors; source specification, LICENSE,
toolchain, entitlements and CI are unchanged. Final-head local evidence and hosted state
are recorded in [GitHub PR #17 — Add reviewed Google sync onboarding and saved privacy preferences](https://github.com/christianzbox/MacHandle/pull/17). The initial app build found a time-zone display accessor mismatch,
corrected before passing validation. Tests use synthetic HTTP and temporary real SQLite,
not live accounts. Unsigned native inspection verified setup/disabled controls, no Calendar
permission prompt on entry, availability default and title-only detail opt-in/back-off.
The test app was quit; no account, real content, login registration or system permission
was used. Exact final pushed-head checks and separate hosted state belong in the GitHub PR.

Live activation is deliberately unavailable, and the specification's end-to-end milestone B
acceptance is still open. [Owned follow-ups](prs/pr-16.md#open-activation-follow-up--not-a-completed-milestone)
retain actual account/client identity, signed Keychain/sandbox, private sharing proof,
trusted source/destination/lifecycle adapters, recovery/transfer UI and isolated-account/
two-Mac acceptance. Engineering and the maintainer revisit after developer setup and
explicit test authorization. These requirements are not silently moved to MCP or waived.
The [setup guide](../development/google-auth-setup.md) remains appropriate for personal
development, without requiring a legal organization, release application or audit purchase.
[Package 17's brief](prs/pr-17.md) is preparation only. Stop for user review.

## Work package 15 evidence — background synchronization

GitHub PR #15 was verified merged at `69a23b9c7a96b8ffc562400a4b9db7642eaf55d2`
on 2026-10-28 11:11:25 America/Detroit (15:11:25 UTC). Its final feature head
`d446c88fc5346547e53ad777294c3e05c58c0100` passed both hosted jobs in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40707249824).
Created `codex/background-synchronization` from fetched main after explicit authorization.
Work Mac remains the sole writer.

[ADR-0020](../architecture/decisions/0020-background-synchronization.md) and the
[acceptance map](prs/pr-15.md#implementation-and-acceptance) describe monotonic periodic
scheduling, source-change debounce/generation invalidation, serialized drain, bounded
preparation retries, fresh executor authority and native workspace/network/login adapters.
Settings exposes only explicit login registration; the app does not activate live sync.

Twenty new Swift tests bring totals to 231 Swift + 13 Python and seventeen negative compiler
probes. Implementation checkpoint
`f524b8ddb6bb4c3fe0dac89572db1276b57582c0` passed all three staged gates: environment
0.20s, full validation 40.86s and pinned history/index scan 1.74s. Initial lint identified
two style issues (block comment and forEach closure), fixed before these passing checks.
Validation included every test/probe, formatting, warnings-as-errors, universal unsigned
Debug/Release builds, analyze and indexed privacy/whitespace checks. Supplemental checks
verified documentation links/anchors/case and all 31 roadmap anchors; specification,
LICENSE, toolchain, entitlements and CI are unchanged. Exact final pushed-head local
checks and separate hosted status are recorded in [GitHub PR #16 — Add serialized background synchronization and opt-in login](https://github.com/christianzbox/MacHandle/pull/16). The scoped optimized idle harness reported zero additional jobs during paused and
active-idle samples; CPU/RSS observations and their limits are recorded in ADR-0020.

No actual login registration, sleep/network/permission change, real account, signed
Keychain or live Google request was performed. Native adapter tests inject signals and
service state. Engineering owns signed login/logout, locked Keychain, App Nap/whole-app
energy, minimum OS and two-Mac acceptance before activation/release. Package 16 owns
trusted source/account/writer composition, persistence/onboarding and live pause/status UI.
Its [brief](prs/pr-16.md) is preparation only. The [setup guide](../development/google-auth-setup.md)
now distinguishes personal development from release enrollment and Apple/Google approval;
no legal organization, submission or commissioned audit is required merely to develop.

## Work package 14 evidence — deletion safety and recovery

GitHub PR #14 was verified merged at `554c4f2cc7914ae4b963f30b28cb529c94f1d3fe`
on 2026-10-28 09:35:11 America/Detroit (13:35:11 UTC). Its final feature head
`1fb6e8a91b9436528e62e0a6eb51e6ef1c459a0f` passed hosted
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40582928927).
Fetched main and created `codex/deletion-safety-recovery` after explicit authorization.
Work Mac remains the sole writer.

[ADR-0019](../architecture/decisions/0019-deletion-safety-recovery.md), the
[acceptance map](prs/pr-14.md#implementation-and-acceptance) and
[recovery procedure](../development/sync-recovery.md) describe exact destructive batch
approval, new-client standby restoration, original prepared intent, lost creation/write
response verification, retained metadata import, verified legacy baseline/source identity
migration and cooperative conditional writer transfer. Recovery preserves remote IDs and
creation history; unresolved evidence never implies deletion or fresh creation authority.
No new module, dependency, schema version, OAuth scope or entitlement is added.

Twenty-one added tests bring totals to 211 Swift + 13 Python tests and sixteen compiler
rejection probes. Implementation checkpoint
`32e2abb6a0f19d62a181e5f64eafca77966a8050` passed all three staged gates: strict
environment 1.05s, full validation 61.42s and pinned history/index secret scan 1.84s.
This includes formatting, warnings-as-errors, all tests/compiler probes, universal unsigned
Debug/Release builds, analyze and indexed privacy/whitespace checks. Documentation links,
anchors and case were checked; the specification, LICENSE, toolchain, entitlements and
CI remain unchanged. Exact final pushed-head local checks and separate hosted status are
recorded in [GitHub PR #15 — Add deletion safeguards and verified synchronization recovery](https://github.com/christianzbox/MacHandle/pull/15).
No real account, source content, Google request or signed runtime is used by these tests.

Live activation remains denied. Trusted account/source identity, confirmation UI, backup
acquisition, canonical store/installation ownership and actual Google/two-Mac acceptance
belong to engineering before package 16 activation. Missing total metadata, uncertain
absence, unavailable original writer and ambiguous transfer stay manual intervention;
there is no forced takeover or silent legacy writer bootstrap. Package 15 owns lifecycle
scheduling. Its [brief](prs/pr-15.md) is preparation only. The existing
[account setup checklist](../development/google-auth-setup.md) remains the maintainer guide.

## Work package 13 evidence — recurrence and time correctness

GitHub PR #13 was verified merged at 1d265050f0e12aa21847b26875e32e12c0d13f4b
on 2026-10-27 16:50:32 America/Detroit (20:50:32 UTC). Its final feature head
b5813309f30ac2e08fc4cb7115dbeee1a4ba09c0 passed hosted
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40578361667).
Fetched main and created codex/recurrence-time-correctness from that squash after
explicit authorization. Work Mac remains the sole writer.

[ADR-0018](../architecture/decisions/0018-recurrence-time-correctness.md) and the
[acceptance map](prs/pr-13.md#implementation-and-acceptance) describe bounded EventKit
materialization, conservative identity guards, explicit local-day horizon, canonical
payload fingerprints and lossless-or-blocked timestamp encoding. Content-v2 is an explicit
compatibility change: v1 baselines conflict until future verified recovery. Local
occurrence/calendar identity versions and durable remote IDs are preserved.

Eighteen new tests bring totals to 190 Swift + 13 Python and fifteen negative compiler
probes. Implementation checkpoint 1040e1f6e77a13c9d051cf265aab5a0fc8f87fd7 passed
all three staged gates: check_environment 0.33s, validate 44.55s and scan_secrets 1.75s.
Validation included all 190 Swift + 13 Python tests, fifteen compiler rejections, formatting,
warnings-as-errors, universal unsigned Debug/Release builds, analyze and indexed privacy/
whitespace checks. 699 local documentation links/anchors/case checks passed; specification,
LICENSE, toolchain, entitlements and CI were preserved. Exact final pushed-head local and
hosted evidence is recorded separately in [GitHub PR #14 — Preserve recurrence identity and canonical calendar times](https://github.com/christianzbox/MacHandle/pull/14).
Synthetic integration uses provider primitive records, the real planner/SQLite/executor/
Google client and an injected HTTP transport. No real source/Google account is accessed.

Local/hosted validation is separate from live behavior. Actual EventKit rule expansion,
detached identifier continuity across resyncs/moves, Google fractional acceptance, signed
privacy/Keychain, minimum OS and home-Mac gates remain open. Engineering owns isolated
provider acceptance before package 16 activation; package 14 owns migration/recovery,
legacy baseline handling and writer transfer. Unsupported finer precision remains blocked
until live evidence justifies a broader exact encoder. The app still cannot activate sync.
The [setup guide](../development/google-auth-setup.md) remains the account/key checklist.
[Package 14's brief](prs/pr-14.md) is preparation only, not authorization to implement.

## Work package 12 evidence — synchronization executor

GitHub PR #12 was verified merged at `567b5a1a644c4b1ccba10eb21687c8d84d5c82cf`
on 2026-10-27 16:20:09 America/Detroit (20:20:09 UTC). Its final feature head
`45a018ccaaa38ede92171227b90a5e04e073b033` passed hosted
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40575657914).
Fetched main and created `codex/synchronization-executor` from that squash after explicit
authorization. Work Mac is the sole writer; home setup remains unverified.

[ADR-0017](../architecture/decisions/0017-synchronization-executor.md) and the
[acceptance map](prs/pr-12.md#implementation-and-acceptance) describe internal ordered
execution with a default-deny trusted authorization contract, committed stable identity,
unknown-before-dispatch, separate remote verification, conditional checkpoints and
read-only recovery. A package-only bridge retains owned Google-session boundaries;
no public provider capability or Apple writer is exposed.

Fifteen synthetic tests combine real temporary SQLite, planner/executor/Google client
and fake HTTP. They cover ordering/convergence, privacy clearing, confirmation, lost
insert/update/delete replies, store reopen, local result failure, partial success,
quota revocation, conflicts, cancellation/concurrency and precision rejection. An
unnecessary test try marker was fixed during the initial warnings-as-errors build.
Repository totals are 173 Swift + 13 Python tests and fifteen compiler rejection
probes. Implementation checkpoint `0c8e09572377c5d1fe5df29e6b0dbbb50ec0ab37` passed
strict preflight (0.31s), full validation (28.35s, including universal builds/analyze)
and pinned history/index scans (1.75s). All 673 local documentation links/anchors/case
checks passed; specification/LICENSE/toolchain/entitlements/CI and 31 package anchors
remain intact.

Review: [GitHub PR #13 — Add durable synchronization execution and verified recovery](https://github.com/christianzbox/MacHandle/pull/13).
Final handoff changes receive fresh gates on the exact pushed head; final SHA, timings
and separate hosted results are recorded in the PR description. Open, not merged.

The app links but never invokes the executor. No live authority/observation adapter,
account, actual HTTP, Apple provider, Keychain or signed runtime was exercised. Recovery
reopens the store/executor while retaining the owned provider session; it does not prove
whole-process ownership reconstruction. Packages 13/14/16 own provider time/identity,
prepared-intent/lost-state recovery, cross-Mac writer transfer and trusted live
freshness/privacy/confirmation/bootstrap composition. Default activation remains denied
until these gates and authorized maintainer setup/signed tests are satisfied. Package 13's
brief is preparation only; no release or next-package implementation is implied.

## Work package 11 evidence — pure reconciliation planner

GitHub PR #11 was verified merged at `4a5ad09a22be45b681c46675d756500603a58d8c`
on 2026-10-27 16:05:30 America/Detroit (20:05:30 UTC). Its final feature head
`96ce84212cafb3cf1be9fc93175c40493491e69b` passed hosted
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40571348961).
Fetched main and created `codex/reconciliation-planner` from that squash after explicit
authorization. Work Mac is the sole writer; home setup remains unverified.

[ADR-0016](../architecture/decisions/0016-pure-reconciliation-planner.md) and the
[acceptance map](prs/pr-11.md#implementation-and-acceptance) describe pure comparison,
versioned deterministic fingerprints, explicit privacy projection, content/version
conflicts, unknown-state gates, guarded deletion and manual intervention. The app links
the module but never invokes it. No SQL/provider dependency or execution authority exists.

Eighteen synthetic public-API tests cover ordering/idempotency, independent digest vector,
privacy reduction and detail minimization, scope/completeness/freshness/identity failures,
missing or corrupt mappings, pending operations, destination edits, deletion evidence,
horizon edges, tombstones, all-day/free/tentative semantics and size bounds. One Swift
Testing macro/key-path compile issue was corrected during development. An added
freshness guard also rejects cached destination observations. Repository totals are
158 Swift + 13 Python tests and thirteen compiler rejection probes. Initial staged
gates passed: preflight 0.34s, full validation 21.17s (including universal builds/analyze),
and pinned history/index scans 1.30s. Implementation commit:
`67c83b4eb04a77d87581c3000924da76bb1b5d31`. All 649 local documentation links/anchors/
case checks passed; specification/LICENSE/toolchain/entitlements/CI and 31 package
anchors are preserved.

Review: [GitHub PR #12 — Add pure deterministic reconciliation planning](https://github.com/christianzbox/MacHandle/pull/12).
Final handoff changes receive fresh gates on the exact pushed head; final SHA, timings
and separate hosted results are recorded in the PR description. Merged in GitHub PR #12
at `567b5a1a644c4b1ccba10eb21687c8d84d5c82cf`; no release.

Provider integration, freshness/absence verification, canonical time conversion and
current policy/ownership/writer enforcement remain packages 12–14 gates. Existing
EventKit cache reads are not authoritative deletion evidence. Every proposed deletion
requires confirmation; no executor, automatic approval, source write, database startup,
live account or Google/Apple call was added or exercised. Package 12's brief was prepared
only in that package. Existing privacy/OAuth/signed/minimum-OS/home-Mac/release gates remain open.

## Work package 10 evidence — SQLite persistence

GitHub PR #10 was verified merged at `928732effe0985ed34a386cba4367ffd69bdc43c`
on 2026-10-27 15:29:13 America/Detroit (19:29:13 UTC). Its final feature head
`0f3ebe3c3ba5c9d1fee7df6e3f051d866fc5e5d8` passed both hosted checks in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40568703866),
rechecked before package 10. Fetched main and created `codex/sqlite-persistence` from
the actual squash SHA after user authorization. Work Mac remains the sole writer.

[ADR-0015](../architecture/decisions/0015-sqlite-persistence.md) and the
[acceptance map](prs/pr-10.md#implementation-and-acceptance) describe isolated SDK SQLite,
explicit create/resume, transactional migrations, identity-bound mappings/fingerprints,
persisted unknown operations, tombstones and conditional checkpoints. Restored values
are candidates requiring remote verification, never Google capabilities or source
completeness evidence. The app links the module but does not construct a store.

Fifteen synthetic storage tests pass against actual temporary SQLite files. They cover
migration/rollback, unknown-outcome restart, atomic result commits, checkpoint conflicts,
private files/local writer exclusion, binding/schema/corruption/missing-file rejection
and abandoned-transaction rollback. Initial development checks exposed macOS canonical
path and file-lock interaction issues; the final design uses libc realpath plus a
separate advisory lock. Temporary diagnostics were removed. Full repository totals
are 140 Swift + 13 Python tests and twelve compiler rejection probes. Implementation
checkpoint `2c2961ab56a6bc58fa0391b3cc92f626f90641d9` passed strict preflight (0.30s),
full validation (22.02s, including universal Debug/Release builds and static analysis),
and pinned history/index secret scans (1.36s). All 628 local documentation links/anchors/
case checks passed; specification/LICENSE/toolchain/entitlements/CI and all 31 package
anchors remain intact.

Review: [GitHub PR #11 — Add versioned SQLite sync persistence](https://github.com/christianzbox/MacHandle/pull/11).
The handoff-only follow-up receives fresh final-head gates; exact SHA, timings and separate
hosted results are recorded in the PR description. Merged in GitHub PR #11 at
`4a5ad09a22be45b681c46675d756500603a58d8c`; not released.

No Google/Apple/Keychain call, live account, private user database, sync, or background
activation was exercised. Synthetic files are removed by fixtures. Metadata is plaintext
under owner-only permissions, not encrypted or authenticated. Local file locks are not
cross-Mac authority. Backup/restore, power-loss/disk-full and signed storage acceptance
remain scoped recovery/release gates. Packages 12/14 own trusted provider integration,
real account/ownership verification, durable-ID bridging and writer transfer; revisit
when those packages and live tests are authorized. Existing OAuth/privacy/setup/home-Mac
and release gates remain open. The package 11 brief was prepared only in that package.

## Work package 09 evidence — Google destination client

GitHub PR #9 was verified merged at `4d80fabae8b2b3a4482b582a48e974656a02eb3f`
on 2026-10-27 15:15:21 America/Detroit (19:15:21 UTC). Its final feature head
`7cb2be6843aa3410cef8fbf90bf0063a8da7d1ed` passed both hosted checks in
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40559302546),
rechecked before package 09. Fetched main and created `codex/google-destination-client`
from the actual squash SHA after user authorization; work Mac is the sole writer.

The [acceptance map](prs/pr-09.md#implementation-and-acceptance) and
[ADR-0014](../architecture/decisions/0014-google-destination-client.md) describe internal
owned calendar/event primitives, If-Match, conservative unknown-outcome handling,
complete-or-error bounded pagination, quota/backoff and session-fenced authentication.
Remote names/markers alone cannot grant ownership. No bearer token API is exposed.

Nineteen new synthetic tests exercise CRUD, removal of prior detail, foreign handles,
marker/version/guest conflicts, interrupted creates, duplicate IDs, 404 verification,
pagination cycles/limits/failures, oversized responses, quota/backoff, refresh coalescing,
401, disconnect/reconnect and cancellation. The focused Google suite passed 41 tests;
repository total is 125 Swift plus 13 Python. Two additional compiler probes reject
external client construction and lease acquisition. Implementation checkpoint `9b5ad89c59e1ab6183d3fc931965d3924fbd61ef` passed strict
preflight (0.32s), full validation (58.50s: 125 Swift + 13 Python tests, zero failures/skips,
eleven probes, universal builds/analyze and repository checks), and pinned history/index
scans (1.99s; no detected leaks). 606 local links/anchors/case checks passed; all 31
packages/legacy anchors and specification/LICENSE/toolchain/entitlements/CI were preserved.

Review: [GitHub PR #10 — Add owned Google calendar destination operations](https://github.com/christianzbox/MacHandle/pull/10). Final handoff-only changes receive fresh gates, with the exact final SHA and separate
local/hosted results in the PR description. Merged in GitHub PR #10 at `928732effe0985ed34a386cba4367ffd69bdc43c`; not released.

App composition and entitlements are unchanged. No Google, Keychain, Calendar or
account/console action was performed; no live privacy or signed-provider claim follows
from these tests. The destination client is internal with no public activation factory.
Persistent identity and pending-operation recovery remain packages 10/14; its in-memory
latches are not crash-safe or cross-Mac protection. Live privacy is deferred to maintainer/
privacy work in 09/16 until a supported account-specific flow exists. Signed activation
is deferred to maintainer/authentication work until setup and isolated-account testing
are authorized. Source transfer remains blocked. At that review, [package 10](prs/pr-10.md) was a brief
only; current persistence evidence is above. No planner/executor, sync or MCP is implied.

## Work package 08 evidence — Google OAuth and Keychain

GitHub PR #8 was verified merged at `34c5c55019d805514117cb41c99adc5c67b1ba9a`
on 2026-10-26 16:34:06 America/Detroit (20:34:06 UTC). Its final feature head
`b26c4e41fef0d065e7a0a397c830df10640714d8` passed hosted
[Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/40393594185),
rechecked 2026-10-27. Fetched main and created `codex/google-oauth-keychain` from
the actual squash SHA after user authorization. Work Mac remains the sole writer.

The [acceptance map](prs/pr-08.md#implementation-and-acceptance) and
[ADR-0013](../architecture/decisions/0013-google-oauth-keychain.md) describe the scoped
implementation. GoogleAuthorization is independent of Calendar/MCP and exposes only
sanitized status/actions to views. It implements PKCE, bounded local callbacks,
fixed-endpoint HTTPS, private Keychain storage, refresh, disconnect and separate
project-grant revocation. Generation checks prevent late results restoring access.
No token-returning public UI API exists; no event API or source-content transfer exists.

Twenty-two new tests cover protocol validation, lifecycle failures/races and private
composition; total 106 Swift tests plus 13 Python tests. Two tests exercise an actual
unsandboxed loopback listener with synthetic callbacks, timeout and cancellation.
Other dependencies are injected; no Google service or actual Keychain item is used.
A ninth compiler probe rejects private credential access. The staged tree committed as `a9755768a80c38eacb04a47fa1197a365896b5b8` passed
strict preflight (0.44s), full validation (56.85s: 106 Swift + 13 Python tests, zero
failures/skips, universal builds/analyze, nine compiler probes and repository checks),
and pinned history/index secret scans (1.37s; no detected leaks). 580 local doc links/
anchors/case checks passed; specification/LICENSE/toolchain/entitlements/CI are
byte-preserved and all 31 packages/legacy anchors retained.

Review: [GitHub PR #9 — Add Google OAuth and private Keychain credentials](https://github.com/christianzbox/MacHandle/pull/9). The final handoff-only commit receives fresh gates; exact final
SHA/local results and independently observed hosted status are recorded in its
description. This historical review merged in GitHub PR #9 at `4d80fabae8b2b3a4482b582a48e974656a02eb3f`; not released.

The universal locally ad-hoc signed Debug app launched, and its Connections page was
inspected with Cmd-2. The separate Google setup notice and disabled Connect button
rendered correctly alongside existing synthetic previews. No Google browser, permission
prompt, real Calendar data or Keychain operation was accessed. This is one-off UI
inspection, not signed OAuth acceptance or maintained UI automation.

The setup guide now includes step-by-step account creation, Apple ownership/signing,
Google console configuration, per-Mac permission boundaries and a public-versus-private
handoff table. Official account/consent guidance was checked on 2026-10-27; no accounts
were created or console settings changed. Final documentation-follow-up gates are
recorded against the pushed head in GitHub PR #9.

The maintainer confirmed that no Apple developer identity or Google OAuth setup exists.
Live activation is deferred, owned by maintainer/authentication work, until identities,
console/test-client configuration and isolated-account authorization exist. Follow the
[activation checklist](../development/google-auth-setup.md), then review composition/
network entitlements and verify signed Keychain/sandbox/Google flows. The app remains
unconfigured with unchanged entitlements; no guessed public IDs, secrets or team settings.
Production consent/brand approval, home-Mac, minimum-OS/Intel and Calendar live gates
remain open. At that review, package 09 was a focused brief only; its current implementation evidence is above. No release or sync is implied.

## Work package 07 evidence — Calendar reads and availability

Prerequisite GitHub PR #7 was verified merged on 2026-10-26 at 15:58:42
America/Detroit (19:58:42 UTC), actual squash SHA
`ab345134daa94f4a4a195ae709e94d6f3d29c7e2`. Fetched origin/main and created
`codex/calendar-reads-availability` from that base. Its predecessor feature head
`08f9182db6b9554b03b86c16e68bc7021be70e99` is distinct from the squash SHA.

The [acceptance map](prs/pr-07.md#implementation-and-acceptance) and
[ADR-0012](../architecture/decisions/0012-calendar-reads-availability.md) describe the
implementation. Nineteen new tests bring Swift coverage to 84 (34 application,
10 Calendar adapter, 21 policy, 18 domain, 1 foundation). Tests use synthetic values,
including provider over-return, original anchors, 23/25-hour DST days, partial coverage,
selection/permission changes and a final authorization check after policy projection.
No test creates a real EventKit store. An eighth compiler rejection prevents OS
permission requests through the read-only protocol.

One-off UI inspection used a disposable native app copy with an injected synthetic
provider and no Calendar entitlement. Availability contained no title/location/notes;
titles omitted location/notes; details displayed the requested synthetic values.
Mode changes and Clear Results removed old content, disable removed read controls,
and partial-coverage messaging and scrolling were inspected. No real OS prompt or
calendar content was accessed. Harness sources/build are outside tracked files and
are removed after inspection; no bypass ships in the app. Real adapter code is compiled
in standard builds, not live-tested. The staged tree committed as `cff1c647f89575b7ad0f72626793c39a41d353f3` passed
strict preflight (0.24s), full validation (24.31s: 84 Swift + 13 Python tests,
zero failures/skips, universal builds/analyze, eight compiler probes and repository
checks), and pinned history/index secret scans (1.49s; no detected leaks). 544 local
documentation links/anchors/case checks passed; source specification/LICENSE/toolchain
are byte-preserved and all 31 work packages/legacy anchors remain.

Review: [GitHub PR #8 — Add bounded Calendar reads and availability](https://github.com/christianzbox/MacHandle/pull/8). The final handoff commit receives fresh standard gates; exact
final SHA/local outcomes and independently observed hosted status are recorded in its
description. GitHub PR #8 is now merged at the SHA above; this section preserves
its historical pre-merge evidence. No release is implied.

Live TCC/sandbox/recurrence checks remain open because this task has no authorized
isolated Calendar account/device. Owner: maintainer/provider work. Revisit on explicit
fixture authorization before milestone A acceptance and in package 13. Home-Mac,
minimum-OS/Intel runtime and release signing remain unverified. At this package 07 checkpoint there were no writes, OAuth,
Google, MCP, persistence, sync or release. Package 08 was then a focused brief only.

## Historical merge and validation evidence

GitHub [PR #1](https://github.com/christianzbox/MacHandle/pull/1) was squash-merged
on 2026-10-23 at 14:14:32 America/Detroit (18:14:32 UTC), actual merge SHA
`4364fb79676de22d07cb6e5c01738481aad1f7d5`. PR-02 rechecked GitHub's merged state,
merge SHA/timestamp and fetched `origin/main` at that commit before branching.
PR-01's final feature head was `75cd96b57ecf180fe1222f5c6f806a4a0aadabf5`;
its [final CI](https://github.com/christianzbox/MacHandle/actions/runs/39999486460)
passed Build and test plus Secret scan. Feature head and squash SHA are distinct.
PR-02 was squash-merged in [GitHub #3](https://github.com/christianzbox/MacHandle/pull/3)
on 2026-10-23 at 15:24:58 America/Detroit (19:24:58 UTC), actual SHA
`c96f4f0cbb54e2397d5c987a80cc2c0cd9ab0630`. Rechecked via GitHub and fetched
origin/main on 2026-10-26 before creating `codex/pr-03-core-domain-models`.
Its final feature head `a51af45bddd9ab6718f175793aa8e45703212043` passed strict
local checks (1 Swift + 13 Python tests, no failures/skips)
and both [hosted jobs](https://github.com/christianzbox/MacHandle/actions/runs/40009355785)
as recorded on that PR. The feature head and squash SHA differ. Historical
pre-merge observations below remain dated evidence.

## Work package 06 Calendar authorization/discovery — 2026-10-26

User authorized one package and a review PR after [GitHub PR #6](https://github.com/christianzbox/MacHandle/pull/6)
was verified merged at `12b4ebf80816dcd307673a64085d00f88bb20981` on 2026-10-26
15:18:26 America/Detroit (19:18:26 UTC). Fetched main and created
`codex/calendar-authorization-discovery`; work Mac remains the only writer.

Implemented a metadata-only CoreDomain contract/catalog, isolated lazy EventKit actor,
and injected CalendarAccessStore with an Apple Calendars page. Enable explains full
OS read/write access before requesting it; this code only lists account/calendar
names. Startup/navigation/refresh never prompt; selections start empty and remain in
memory. Disable, revoked/uncertain reads and cancellation invalidate data; generations
discard late results and coalesce refresh. Foreground/window/store-change signals
refresh enabled discovery. No events, mutations, external connections or persistence.

[ADR-0011](../architecture/decisions/0011-calendar-authorization-discovery.md) and the
[acceptance map](prs/pr-06.md#implementation-and-acceptance) record contracts,
alternatives and limits. The Calendar entitlement/usage description are the only
new OS capabilities; effective built Info.plist and signed entitlements were checked.
Specification/LICENSE/toolchain and CI protections remain unchanged. The
[package 07 brief](prs/pr-07.md) was planned only at this historical checkpoint.

Focused checks: 65 Swift tests (23 application, 2 Calendar adapter, 21 policy,
18 domain, 1 foundation) pass. Fifteen new application tests include disabled startup,
opt-in/refusal, identity/selection, revocation, async races/cancellation and observable
UI updates. Two adapter tests map SDK authorization and deliver a synthetic notification
without loading a real store. The default locally signed universal Debug app launched
with discovery off; Cmd-5 and its explanation/accessible controls were inspected.
A disposable native harness with synthetic provider and no Calendar entitlement
verified selection/count updates, disable clearing, and denied/incomplete/unavailable/
local-empty screens. This caught and corrected missing selection observation. Harness,
screenshots and logs remain outside Git; no real permission request or metadata access.

Live TCC grant/deny/revoke, sandbox enforcement and actual account discovery are
**unverified** because no isolated account/device was authorized in this session.
Maintainer/provider work owns this package 06/07 runtime gate before live claims.
Home-Mac/macOS 14/Intel and release signing remain separate gates. No scanner or
synthetic test establishes those results.

[GitHub PR #7 — Add opt-in Calendar authorization and discovery](https://github.com/christianzbox/MacHandle/pull/7) is open for review.
The exact staged tree committed as `655b714b7e5d12b275f44e1b48d197296346537c` passed
strict preflight (0.21s), full validation (21.60s: 65 Swift + 13 Python tests, no
failures/skips, compiler boundaries, builds/analyze, formatting/privacy/whitespace),
and pinned history/index secret scans (1.45s; no detected leaks). 521 local doc
links/anchors/case checks passed; all 31 packages/legacy anchors retained and
specification/LICENSE/toolchain bytes preserved. The final handoff-only commit gets
fresh gates; exact final head and local/hosted results belong on GitHub PR #7.

## Work package 05 native application — 2026-10-26

User authorized work package 05 and a review PR. Verified predecessor
[GitHub PR #5](https://github.com/christianzbox/MacHandle/pull/5) merged at
`0cdac4bd5845b2b167a48c00332ef5ddf5080606` on 2026-10-26 14:57:29 America/Detroit
(18:57:29 UTC), then fetched main and created `codex/native-application-foundation`.
Work Mac remains the sole writer; physical home-Mac setup remains unverified.

Implemented native Overview/Connections/Activity/Diagnostics, Settings and MenuBarExtra,
plus MacHandleApplication presentation/service composition. Sample connections start
disabled with no selections, use isolated synthetic policy authorities and cannot
connect any account or grant writes. Old decisions clear during edits and fresh
sessions revalidate current policy; bounded history and preferences are memory-only.
[ADR-0010](../architecture/decisions/0010-native-application-foundation.md) records
alternatives/tradeoffs. The [acceptance map](prs/pr-05.md#implementation-and-acceptance)
routes requirements to evidence; [package 06](prs/pr-06.md) remains planned only.

Focused checks: 48 Swift tests (8 application + 21 policy + 18 domain + 1 foundation)
passed. Default locally signed universal Debug build launched on the work Mac.
Native AX/screenshot inspection checked labels/roles, Cmd-1/2/3/4 navigation,
Cmd-comma Settings, empty-selection denial, selected-calendar allow, revoke/activity
feedback, and system-light/dark appearance. Window close retained the process; Quit
terminated it. Settings height was increased and reinspected; a fresh launch reset sample choices
and appearance as expected.
No screenshot or private diagnostic output is committed.

Direct menu-bar status-item click/reopen remains a manual review check because the
current automation surface exposes the app menu but not that item. Broader VoiceOver,
increased contrast, oldest-OS/home-Mac, distribution signing, sandbox enforcement,
actual authorization and live-provider checks remain unverified. Those limits do not
become passing claims from builds or the synthetic tests. No entitlements, credentials,
real data, network listener or global tool settings changed.

[GitHub PR #6 — Build native application foundation](https://github.com/christianzbox/MacHandle/pull/6) merged at
`12b4ebf80816dcd307673a64085d00f88bb20981`; the following pre-merge evidence is historical. The exact staged tree committed as
`2f881edf3cf988baa0e7550489460e1e8cc75363` passed strict preflight (0.28s), full
validation (34.52s: 48 Swift + 13 Python tests, no failures/skips, compiler boundaries,
builds/analyze, formatting/privacy/whitespace) and pinned history/index secret scans
(1.83s; no detected leaks). 497 local links/anchors/case checks passed, all 31 work
packages/legacy anchors remain, and specification/LICENSE/entitlements/toolchain
bytes are unchanged. The final handoff-only commit receives fresh checks; its exact
head and local/hosted results belong on GitHub PR #6 to avoid self-reference.

## Work package 04 permission policy engine — 2026-10-26

User authorized implementation and a GitHub PR for review. Predecessor work package
03 was verified merged in GitHub PR #4 at `a990e05721e75770df98ba01c2bad2bc5aa731a7`
on 2026-10-26 at 14:38:37 America/Detroit (18:38:37 UTC). Fetched main before
creating `codex/permission-policy-engine`; only the work Mac is the active writer.
Historical work-package labels below retain their original PR-NN wording; the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs) distinguishes them from
GitHub PR numbers. New GitHub titles describe the change without a roadmap prefix.

Implemented PermissionEngine as one CoreDomain-only target. It includes default-deny
resource/operation/read/write field grants; independent OS observations; exact
source selection; trusted actor-owned configuration and bound narrow sessions;
immutable exact-request receipts; policy/OS generation invalidation; revocation;
and response projections that recheck current policy. Google Sync cannot gain
source mutations or other Apple services. Contact search checks hidden predicate
fields, subset filtering refuses unresolved unified data, and all writes still
require future local approval/current provider checks.

[ADR-0009](../architecture/decisions/0009-permission-policy-engine.md) and the
[acceptance map](prs/pr-04.md#implementation-and-acceptance) document decisions,
alternatives, invariants and limits. The next [native application brief](prs/pr-05.md)
is planned only. No app integration, provider, TCC prompt, live authentication,
local approval token, persistence, network or real account data is introduced.
Unified-contact provenance (packages 24/25), provider race/atomicity, current revision
comparison, signed/oldest-OS and home-Mac evidence remain later gates with explicit owners.

[GitHub PR #5 — Add permission policy engine](https://github.com/christianzbox/MacHandle/pull/5)
merged at `0cdac4bd5845b2b167a48c00332ef5ddf5080606`; the following pre-merge
evidence remains historical. The exact staged tree committed as
`1435d7710e3218e71be1bca8b8d13ff668b2a876` passed strict preflight (0.34s), full
standard validation (14.31s) and pinned history/index secret scans (2.27s; no detected
leaks). Validation ran 40 Swift tests (21 policy + 18 domain + 1 foundation), 13 Python
tests, zero failures/skips; dependency/import guards, positive compiler control,
seven expected rejections, formatting, package build/test, unsigned Debug/Release
builds and analysis, indexed privacy and whitespace. 473 local documentation
links/anchors/case checks passed; all 31 work packages and legacy anchors remain;
specification/LICENSE byte equality verified. The final handoff-only commit gets
fresh standard checks, with exact final head/local/hosted status on GitHub PR #5.
Earlier evidence does not assert that a later commit passed.

## PR-03 core domain — 2026-10-26

User authorized PR-03 after confirming no home-Mac work had started. Branch created
from the verified PR-02 squash SHA above; only the work Mac is the active writer.
Home-Mac setup remains unverified and is not a prerequisite for pure model work.

Implemented `CoreDomain` as one independent SwiftPM library target: typed local
identity namespaces and disabled connection defaults; explicit authorization states;
finite/half-open time and civil dates; calendar occurrences with original anchors;
nonempty selections and observed coverage/completeness/freshness; availability without
event detail; Reminder due/completion separation; Contact field/identity distinctions;
typed patches/proposals/preconditions and conflict/failure/unknown mutation outcomes.
CalendarReading and CalendarWriting are separate async interfaces with no provider
implementation. The app still links only the existing foundation metadata.

[ADR-0008](../architecture/decisions/0008-core-domain-contracts.md) records alternatives,
tradeoffs, representation limits and later owners. [PR-03's acceptance map](prs/pr-03.md#implementation-and-acceptance-map)
routes requirements to evidence; at that checkpoint [work package 04](prs/pr-04.md)
was planned only. Its current implementation is recorded above. No roadmap package or product requirement is dropped.

[GitHub PR #4](https://github.com/christianzbox/MacHandle/pull/4) merged at
`a990e05721e75770df98ba01c2bad2bc5aa731a7`; the following pre-merge checkpoints
remain historical evidence.
The exact staged tree committed as `319efed537baa039a96c8980d09b35447d336d05`
passed strict preflight (0.21s), full validate (8.56s), and pinned secret scanning
(1.47s; history/index; no detected leaks). Validation included 18 CoreDomain + 1
foundation Swift tests and 13 Python tests, zero failures/skips; formatting, package
build/test, unsigned Xcode Debug/Release builds and analysis, indexed privacy and
whitespace. Domain dependency/import guard, positive compile control and all three
expected rejections passed. 446 local links/anchors/case checks passed; spec/LICENSE
are byte-identical to main; all 31 roadmap entries remain. The handoff-only final
commit and its fresh local/hosted results are recorded on PR #4; historical checkpoint
evidence does not assert that a later head passed.

No live providers, permissions, accounts, policy engine, approvals, persistence,
sync, MCP or UI features added. Tests establish model/static behavior only. All-day
query filtering, upstream freshness, resync/move identity, actual provider concurrency,
trusted approvals, signed/oldest-OS runtime and home-Mac setup remain later gates.
No credentials, real fixtures, entitlements, toolchain baseline or CI permissions changed.

## Verified checkpoints

| Snapshot | Evidence | Result and limits |
| --- | --- | --- |
| `fa4bfd399a95b54e5461b7e4cf3488ea3c29e104` | PR-02 [GitHub #3](https://github.com/christianzbox/MacHandle/pull/3), [checkpoint CI](https://github.com/christianzbox/MacHandle/actions/runs/40007318162) | Strict local preflight (0.2s), validation (5.4s), scanner (1.2s) passed; 1 Swift + 13 Python tests, no failures/skips; Debug/Release/analyze/format/privacy; no detected leaks. 420 doc links/anchors/case checks, spec/LICENSE preservation and 31 roadmap entries passed. Both hosted jobs passed on this exact head (Build and test 1m59s; Secret scan 6s); final evidence-only head is recorded on the PR. No live integration proof. |
| `3a13185d9825051d3385a9b651934a6924cce66a` | [Foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/39985663775) | Initial skeleton/security checks passed. Hosted Xcode 26.6 differed from local 27.1; historical baseline only. |
| `d2aed09e74419562e6b655b6319e1367d0971c41` | [Portable-development CI](https://github.com/christianzbox/MacHandle/actions/runs/39988488252), [PR #1 evidence](https://github.com/christianzbox/MacHandle/pull/1) | Exact Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0 verified locally and hosted. Debug/Release builds, analyze, formatting, 1 Swift + 12 Python tests, privacy/secret checks passed. Fresh GitHub clone with spaces/no transferred cache passed (24.9s validation, 1.2s scanner). No detected secrets. |
| `425ca3c0c09a20fe14e283a0a9671f829f7ea7a4` | [Documentation-foundation CI](https://github.com/christianzbox/MacHandle/actions/runs/39991683940) | Local strict validation and both hosted checks passed; 1 Swift + 12 Python tests; 364 local documentation links/anchors, exact-case paths, original source/license equality and all 31 roadmap routes verified. Not merged. |

Documentation consolidation checks (2026-10-23 working snapshot): all local
Markdown links/anchors and exact-case paths passed; all 31 original PR IDs/titles
match the source and have master-plan routes; no old duplicate Docs tree remains.
The canonical specification matches both the original attachment and the prior
Git blob byte-for-byte (SHA-256 in the [documentation map](../README.md)); LICENSE
matches main. These disposable checks verify preservation/navigation, not product
behavior. Pre-commit strict validation also passed on the shared baseline: Debug
and Release builds, Xcode analysis, formatting, 1 Swift + 12 Python tests, indexed
privacy checks and history/index secret scans (no detected leaks). The commit
carrying this change is identified by Git history; the PR
records its exact tested head and final local/hosted results after push.

The second checkpoint proves independent clean-clone development on the work Mac
and CI, not physical home-Mac setup, minimum-OS compatibility, runtime sandboxing,
or real provider behavior. New commits need new check evidence; the prior table
is not a claim that future changes passed. Latest-head results and exact tested SHA
are recorded on the existing PR; record additional checkpoints here when the next
PR/handoff is prepared. [Testing commands](../development/testing.md) remain authoritative.

## PR-01 requirement-review follow-up

Reviewed the original handoff and the documentation/two-Mac additions using the
[acceptance map](prs/pr-01.md#requirement-review--2026-10-23). Fixed preflight ordering:
Xcode selection now precedes the Apple Python launcher probe, avoiding dependence
on a usable global developer selection. The new synthetic regression test failed
before the fix and passed afterward; all 13 Python tests passed. The earlier
checkpoint counts above remain historical (12 Python tests).

Clarified that the app scheme has no test targets and package tests run through
`validate.sh`; restored product purpose in AGENTS and Swift-choice rationale in
ADR-0001. A clean Debug build using default development signing passed (10.7s),
with "Sign to Run Locally" and no developer team or signing override. This is
build evidence only, not launch, sandbox or Developer ID evidence. Repository
visibility/protections were re-read and remain as documented below.

Pre-commit standard validation passed on Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0:
1 Swift + 13 Python tests, Debug/Release builds, analysis, formatting, indexed privacy
and history/index secret scans (no detected leaks). All 371 local Markdown links,
exact-case paths and anchors passed; source/license/README/ignore-rule preservation
and the complete 31-PR register were rechecked.

Final local/hosted validation and fresh-clone results for this review commit are
recorded on [PR #1](https://github.com/christianzbox/MacHandle/pull/1), with the exact
pushed head. Home-Mac hardware/OS validation remains outstanding; no PR-02 work began.

## PR-02 feasibility evidence — 2026-10-23

Implemented documentation only on `codex/pr-02-technical-feasibility`:

- [ADR-0004](../architecture/decisions/0004-platform-and-apple-apis.md): macOS 14,
  exact toolchain retained; EventKit full access versus policy, recurrence/coverage
  constraints, Contacts field minimization and device-local identity.
- [ADR-0005](../architecture/decisions/0005-google-desktop-boundary.md): desktop
  browser PKCE/loopback, method scope audit, privacy/recovery and consent gates.
- [ADR-0006](../architecture/decisions/0006-local-mcp-and-processes.md): stdio adapter
  and trusted broker, current/legacy protocol boundary, local pairing/revocation,
  signed external-helper IPC feasibility still required.
- [ADR-0007](../architecture/decisions/0007-lifecycle-identity-and-distribution.md):
  opt-in login and scheduling, stable identity/Keychain strategy, release gates.
- PR-03's brief now specifies typed authorization/coverage/identity/time/field and
  mutation-precondition constraints. No PR-03 models or providers were implemented.

Official documentation was inspected on this date; each ADR links exact sources
and distinguishes design inferences from guarantees. Disposable Swift 6 typechecks
at the PR-01 base passed for macOS 14 arm64 and x86_64 using the pinned toolchain.
A negative Contacts `.limited` probe failed as expected: unavailable in macOS.
The [brief](prs/pr-02.md#evidence-and-experiments) records symbols, flags and limits.
No probe function ran; no retained prototype, new runtime dependency or test target.

Local standard checks and hosted results for committed PR-02 snapshots are recorded
in [coordination](pr-coordination.md) and the active PR, with exact SHAs. Source
research/typechecking does not verify TCC, sandbox runtime, XPC peer rejection,
Google accounts, MCP clients, background execution, signing or notarization.
Home-Mac hardware remains untested. No personal data, accounts, permission prompts,
credentials, entitlements or global tool settings were accessed/changed.

Remaining gates have reasons/owners/triggers in ADRs and the master open-decision
register. Notably: private Google destination verification under narrow scope,
lost-ID recovery, signed external-helper IPC and pairing, final production identity,
and oldest-OS runtime tests. They gate their later features, not PR-03 pure models.
No product requirement is dropped or silently broadened.

### PR-02 requirement-review corrections

Reviewed GitHub #3 at `07dffb7553c058b8bbfbe8bc71e05f3ca870f9c8` against the focused
brief, original nine-topic PR-02 scope and relevant security/API requirements.
The [review map](prs/pr-02.md#requirement-review--2026-10-23) records four corrected
documentation gaps: Google project-grant revocation breadth/delay, conditional writes
and uncertain-insert recovery, conflicting custom-redirect guidance, and a complete
reproducible compile-only recipe. Updated PR-03's revision/unknown-outcome constraint
without implementing models, plus privacy/security and the master decision register.

The documented recipe was executed directly: arm64/x86_64 macOS 14 typechecks passed,
and native macOS Contacts `.limited` produced the required rejection. No provider
code ran. Final correction-commit standard checks, hosted results and exact SHA are
recorded on the same PR; earlier results above remain historical. No new runtime,
permissions, tests of real accounts or expanded work-package scope.

## Repository configuration observed

Public `christianzbox/MacHandle`; Apache-2.0 retained; `main` default; squash-only
merges, delete merged branches, auto-merge disabled. Main ruleset 25734616 requires
PRs, linear history, conversation resolution, no force-push/deletion, zero required
approvals and no bypass actors. It requires `Build and test` and `Secret scan` from
GitHub Actions (15368), with up-to-date branches. Existing protections were preserved.
Secret scanning and push protection were enabled. These dated settings are distinct
from merged code; re-read them when making protection or release claims.

## Known limitations and unresolved decisions

- Calendar discovery and bounded local reads/availability are merged. Actual
  EventKit/TCC/sandbox behavior remains unverified. Google auth code is implemented
  for review with activation disabled. No event writes, active Google authentication,
  sync, MCP, Reminders/Contacts/Notes providers, content persistence, approval issuer
  or complete product UI exists. Synthetic previews remain separate from real reads.
- Scoped work-Mac launch/UI inspection exists above; no runtime sandbox, minimum-OS, real-account, independent
  security audit, Developer ID signing, notarization or public release proof exists.
- [ADR-0004](../architecture/decisions/0004-platform-and-apple-apis.md) selects macOS
  14 for implementation, with API/typecheck evidence only. Oldest-OS runtime remains
  untested. The development bundle ID is unchanged; production registration and
  signed Keychain continuity remain [ADR-0007](../architecture/decisions/0007-lifecycle-identity-and-distribution.md) gates.
- The work Mac matches the shared baseline; the home Mac is untested. GitHub's
  `xcode-27` runner is preview. [ADR-0002](../architecture/decisions/0002-portable-development.md)
  records why this baseline is required and the availability/compatibility limits.
- Compiler/analyze/scan success is not a complete security/privacy guarantee. The
  foundation Swift test is harness evidence; PR-03 adds model invariants/static boundaries.
  Work package 04 adds synthetic policy tests; provider tests arrive in their owning packages.
- Future decisions and their owners are in the master's
  [open-decision register](../../plans/MacHandleMasterImplementationPlan.md#unresolved-decisions-and-deferred-scope).
  Do not silently resolve them in a summary or conflate planned APIs with working integrations.

## Deferrals

No entire roadmap work package has been formally deferred or dropped. Package 23 capability limits
(recurrence mutations, alarm-bearing targets/edits and list moves) have explicit engineering ownership
and isolated-provider revisit triggers in [ADR-0028](../architecture/decisions/0028-reminders-management.md). Notes integration
(PR-27), remote activation (PR-28), and plugin packaging (PR-31) remain **conditional
planned**. Their future decision records must say which capabilities are feasible,
what is deferred, why, who owns it, and what evidence would trigger reconsideration.

The original future-extension scope (iCloud Drive, Photos, additional providers,
Microsoft 365) is outside the initial release commitment under specification §3.5.
Reason: maintain incremental scope and avoid speculative permissions/infrastructure.
Revisit only through an explicit scoped proposal with supported-API/privacy evidence.
Features excluded from PR-01 are still planned; exclusion is not abandonment.

## Update contract

Every PR updates this file with implemented changes, exact validation evidence and
limits, outstanding work/deferrals, and affected decision links. Update roadmap
state and coordination alongside it. After user merge, verify the GitHub merge SHA
and record it here and in coordination during the next authorized PR. Preserve
previous checkpoints instead of rewriting history as if old results covered new code.
