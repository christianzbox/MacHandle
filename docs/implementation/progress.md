# Implementation progress

Updated: 2026-10-23. This file records actual implementation and evidence, not the
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
| PR-02 feasibility | ADRs 0004–0007, official source audit, PR-03 domain constraints | Disposable API typechecks; standard check evidence below/PR | Active branch; not merged; no integrations |
| PR-03–07 remainder of foundation | Planned: domain/policy, full native shell, Calendar permissions/reads | No provider/policy/UI feature evidence yet | Not merged; milestone A incomplete |
| PR-08–16 Google synchronization | Planned: OAuth, destination, persistence, planner/executor, recurrence/recovery/background/onboarding | No connected Google service or sync evidence | Not merged |
| PR-17–25 MCP, Reminders, Contacts | Planned: protocol/identity/approval and scoped service reads/writes | No live MCP, mutation, Reminders or Contacts evidence | Not merged |
| PR-26–31 Notes, remote, hardening/distribution | Planned decision gates; PR-27/28/31 conditional on supported safe capabilities | No Notes feasibility verdict, audit, signing/notarization or plugin approval | Not merged; no release |

GitHub [PR #1](https://github.com/christianzbox/MacHandle/pull/1) was squash-merged
on 2026-10-23 at 14:14:32 America/Detroit (18:14:32 UTC), actual merge SHA
`4364fb79676de22d07cb6e5c01738481aad1f7d5`. PR-02 rechecked GitHub's merged state,
merge SHA/timestamp and fetched `origin/main` at that commit before branching.
PR-01's final feature head was `75cd96b57ecf180fe1222f5c6f806a4a0aadabf5`;
its [final CI](https://github.com/christianzbox/MacHandle/actions/runs/39999486460)
passed Build and test plus Secret scan. Feature head and squash SHA are distinct.
PR-02 is not merged. Historical pre-merge observations below remain dated evidence.

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

- The app has no Apple data access, OAuth, sync, MCP, Reminders, Contacts, Notes,
  policy engine, persistence, approvals or complete product UI. All services are absent.
- No launch/UI automation, runtime sandbox, minimum-OS, real-account, independent
  security audit, Developer ID signing, notarization or public release proof exists.
- [ADR-0004](../architecture/decisions/0004-platform-and-apple-apis.md) selects macOS
  14 for implementation, with API/typecheck evidence only. Oldest-OS runtime remains
  untested. The development bundle ID is unchanged; production registration and
  signed Keychain continuity remain [ADR-0007](../architecture/decisions/0007-lifecycle-identity-and-distribution.md) gates.
- The work Mac matches the shared baseline; the home Mac is untested. GitHub's
  `xcode-27` runner is preview. [ADR-0002](../architecture/decisions/0002-portable-development.md)
  records why this baseline is required and the availability/compatibility limits.
- Compiler/analyze/scan success is not a complete security/privacy guarantee. The
  Swift test is harness evidence only; meaningful provider/policy tests arrive later.
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
