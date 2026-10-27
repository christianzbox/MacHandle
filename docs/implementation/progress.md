# Implementation progress

Updated: 2026-10-27. This file records actual implementation and evidence, not the
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
| Work package 09 Google destination | Internal owned destination/event client, private authenticated transport, pagination and conditional writes | Synthetic fixtures and session/concurrency tests; full gates recorded below/PR | Implemented for review; not merged |
| PR-10–16 Google synchronization | Planned: persistence, planner/executor, recurrence/recovery/background/onboarding | No connected Google service or sync evidence | Not merged |
| PR-17–25 MCP, Reminders, Contacts | Planned: protocol/identity/approval and scoped service reads/writes | No live MCP, mutation, Reminders or Contacts evidence | Not merged |
| PR-26–31 Notes, remote, hardening/distribution | Planned decision gates; PR-27/28/31 conditional on supported safe capabilities | No Notes feasibility verdict, audit, signing/notarization or plugin approval | Not merged; no release |

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
local/hosted results in the PR description. Not merged or released.

App composition and entitlements are unchanged. No Google, Keychain, Calendar or
account/console action was performed; no live privacy or signed-provider claim follows
from these tests. The destination client is internal with no public activation factory.
Persistent identity and pending-operation recovery remain packages 10/14; its in-memory
latches are not crash-safe or cross-Mac protection. Live privacy is deferred to maintainer/
privacy work in 09/16 until a supported account-specific flow exists. Signed activation
is deferred to maintainer/authentication work until setup and isolated-account testing
are authorized. Source transfer remains blocked. [Package 10](prs/pr-10.md) is a brief
only; no SQLite, planner/executor, sync, MCP, merge or publication is included.

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

No roadmap work package has been formally deferred or dropped. Notes integration
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
