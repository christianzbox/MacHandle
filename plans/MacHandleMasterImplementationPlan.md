# MacHandle — Master Implementation Plan

Status: authoritative execution roadmap. Updated: 2026-10-29.

MacHandle is a native macOS personal-information integration layer: independently
manage selected Apple resources, synchronize to optional destinations, and connect
authorized applications/AI clients. Develop one reviewable PR at a time. This plan
organizes delivery; it does not authorize implementing the whole product now.

## Authority and document roles

| Document | Authority |
| --- | --- |
| [Full product specification](../docs/product/master-spec.md) | Canonical product vision, requirements, constraints, behaviors, and original 31-PR baseline. Read relevant sections; do not replace it with a summary. |
| **This master plan** | Execution strategy, phase/milestone gates, sequencing rules, architectural constraints, and unresolved decision owners. There is only one master implementation plan. |
| [PR roadmap](../docs/implementation/pr-roadmap.md) | Detailed ordered register subordinate to this plan: each PR's dependency, scope, acceptance, reading route, and current delivery status. |
| [Focused briefs](../docs/implementation/prs/README.md) | Concrete scope/contracts/tests for one eligible PR; refine with prerequisite evidence. |
| [Progress](../docs/implementation/progress.md) | What actually exists, what was verified and how, what merged, and what remains unverified/deferred. |
| [PR coordination](../docs/implementation/pr-coordination.md) | Active branch/PR, merge dependencies, checkpoint references, and next action across sessions/Macs. |
| [Architecture](../docs/architecture/overview.md) and [ADRs](../docs/architecture/decisions/README.md) | Actual/planned boundaries and reasons, alternatives, tradeoffs, consequences, and decision status. |

The original specification's proposed `Docs/` paths and reusable prompt are retained
as supplied. The current path map and subsequent workflow requirements are in
[the documentation index](../docs/README.md) and [ADR-0003](../docs/architecture/decisions/0003-documentation-authority.md).
Its original roadmap is a requirements baseline, not a second live progress ledger.
Explicit subsequent workflow decisions govern navigation/toolchain/coordination;
they do not silently delete product requirements. If a genuine product requirement
changes, amend the canonical specification deliberately, record the reason and
superseded decision in an ADR, and reconcile this plan, roadmap, brief, and evidence.

## Delivery sequence and all planned work packages

The six engineering stages below retain all 31 original work packages. The linked
roadmap rows own detailed dependencies and acceptance; the lists here are navigation,
not duplicate briefs. Refer to steps as **work package NN** and actual reviews as
**GitHub PR #N**. Legacy PR-NN labels/paths/anchors remain for specification traceability;
GitHub titles describe the change without those number prefixes. The
[roadmap mapping](../docs/implementation/pr-roadmap.md#work-packages-and-github-prs)
records actual review links; never infer a GitHub number from a work-package number.

| Stage | Ordered work packages | Stage gate |
| --- | --- | --- |
| A — Project foundation | [01 Repository/security](../docs/implementation/pr-roadmap.md#pr-01), [02 Feasibility/ADRs](../docs/implementation/pr-roadmap.md#pr-02), [03 Domain models](../docs/implementation/pr-roadmap.md#pr-03), [04 Permission engine](../docs/implementation/pr-roadmap.md#pr-04), [05 Native app foundation](../docs/implementation/pr-roadmap.md#pr-05) | Safe repository and reproducible development; isolated domain/policy tests; native UI uses mock state until providers are ready. |
| B — Calendars and Google | [06 Authorization/discovery](../docs/implementation/pr-roadmap.md#pr-06), [07 Reads/availability](../docs/implementation/pr-roadmap.md#pr-07), [08 OAuth/Keychain](../docs/implementation/pr-roadmap.md#pr-08), [09 Google client](../docs/implementation/pr-roadmap.md#pr-09), [10 SQLite](../docs/implementation/pr-roadmap.md#pr-10), [11 Planner](../docs/implementation/pr-roadmap.md#pr-11), [12 Executor](../docs/implementation/pr-roadmap.md#pr-12), [13 Recurrence/time](../docs/implementation/pr-roadmap.md#pr-13), [14 Deletion/recovery](../docs/implementation/pr-roadmap.md#pr-14), [15 Background sync](../docs/implementation/pr-roadmap.md#pr-15), [16 Onboarding](../docs/implementation/pr-roadmap.md#pr-16) | Selected Apple reads and verified one-way Google mirroring; deterministic, recoverable execution with no original-calendar writes. |
| C — Local MCP | [17 Transport](../docs/implementation/pr-roadmap.md#pr-17), [18 Reads](../docs/implementation/pr-roadmap.md#pr-18), [19 Identity/revocation](../docs/implementation/pr-roadmap.md#pr-19), [20 Approval engine](../docs/implementation/pr-roadmap.md#pr-20), [21 Calendar mutations](../docs/implementation/pr-roadmap.md#pr-21) | Authenticated/authorized reads, exact locally approved writes, and effective revocation. No live client exposure before identity/policy gates are ready. |
| D — Reminders | [22 Provider/reads](../docs/implementation/pr-roadmap.md#pr-22), [23 Approved management](../docs/implementation/pr-roadmap.md#pr-23) | Independent list permissions and safe, tested reminder management. |
| E — Contacts and experimental Notes | [24 Contacts reads](../docs/implementation/pr-roadmap.md#pr-24), [25 Contacts writes](../docs/implementation/pr-roadmap.md#pr-25), [26 Notes feasibility](../docs/implementation/pr-roadmap.md#pr-26), [27 Optional Notes](../docs/implementation/pr-roadmap.md#pr-27) | Field minimization and deletion safeguards; Notes implementation only after a supported, safe feasibility decision, otherwise a documented deferral. |
| F — Remote integration, hardening, distribution | [28 Secure remote MCP](../docs/implementation/pr-roadmap.md#pr-28), [29 Diagnostics/audit/UX](../docs/implementation/pr-roadmap.md#pr-29), [30 Release engineering](../docs/implementation/pr-roadmap.md#pr-30), [31 Plugin packaging](../docs/implementation/pr-roadmap.md#pr-31) | Audit and verify advertised capabilities; signed/notarized releases; remote/plugin activation only when supported and approved. |

Default sequencing is conservative and serial. Detailed dependencies are in the
roadmap; every prerequisite must be verified merged before implementation. This is
work sequencing, not runtime coupling: Google sync must not depend on AI/MCP being
enabled, and MCP must not require Google. A proposed reorder needs a recorded
execution decision and updated dependencies, not silent scope expansion.

PR-26 is a mandatory decision gate. PR-27 may deliver only a documented deferral.
PR-28 must conclude with either validated secure support or an explicit deferral;
that decision can unblock PR-29 without shipping unsupported remote functionality.
PR-31 may be deferred due to external distribution constraints. Conditional is not
synonymous with deferred: record an actual decision, reason, owner, and revisit
trigger before changing a work package to Deferred. Neither Notes nor plugin
approval may force unsafe scope or block an otherwise safe, accurately scoped release.

## Release milestones and acceptance

Engineering stages and releases differ. Preserve the original specification's
milestone boundaries; do not equate merged code with a released or accepted product.

| Milestone | Work packages | Required evidence before claiming the result |
| --- | --- | --- |
| A — Foundation | PR-01–07 | Protected public repository; native shell; tested policy engine; authorized selected-calendar reads. PR-01 alone does not complete this milestone. |
| B — Google sync alpha | PR-08–16 | Synthetic/isolated-account end-to-end mirroring, repeat-run idempotency, privacy modes, interrupted-write/deletion recovery, and background/onboarding evidence. |
| C — Local Calendar MCP beta | PR-17–21 | Protocol interoperability, authenticated per-connection reads, trusted local approvals, mutation conflict checks, revocation, and synthetic write tests. |
| D — Personal-information integrations | PR-22–27 | Independent Reminders and Contacts permissions and verified scoped behavior; Notes only as justified by PR-26/27, with limitations disclosed. |
| E — Public distribution | PR-28–31 or documented readiness adjustment | Audited supported services, accessible/recoverable UX, signed/notarized packaging, checksums/install/update guidance, and real remote/plugin compatibility/approval where advertised. |

Apply [specification §25](../docs/product/master-spec.md#25-final-product-acceptance-criteria)
to the release's actual promises. Require [security/privacy](../docs/architecture/security-model.md)
and [testing](../docs/development/testing.md) evidence, and follow [release policy](../docs/releases.md).
No production-ready, connection-success, audit, notarization, or platform-approval
claim follows merely from unit tests or public source. No milestone is currently released.

## Architecture and security constraints

- Native Swift/SwiftUI; AppKit only as needed. Domain contracts remain independent
  of UI, EventKit, Google payloads, transports, and SQLite internals. Create cohesive
  modules incrementally, not dozens of speculative packages.
- Native public APIs only. Notes uses supported Automation/Shortcuts if feasible;
  no private frameworks or internal-database manipulation.
- Keep macOS authorization, connection policy, and trusted local approval separate.
  EventKit full access is OS-level read/write; app-level read-only must be enforced
  and accurately disclosed. Defaults are disabled and independently scoped per service.
- All privileged operations check authenticated identity, selection, operation,
  field visibility, approval, revocation, and current mutation preconditions.
  Resource text is untrusted input. Caller names and AI assertions confer no authority.
- Sync only receives source-read capabilities. Use a private app-owned Google
  calendar and narrow scope, default availability-only privacy, validated complete
  snapshots, safe identity/mapping, idempotent planning, and crash-safe execution.
  Missing accounts, revoked permissions, partial reads, or corrupt state never
  authorize destructive reconciliation. Multi-Mac sync has one active destination writer.
- Secrets belong in Keychain; logs/fixtures/exports must not leak content. No default
  MacHandle-operated cloud collection and no unauthenticated remote endpoint.
- Work/home development uses the same checked-in configuration and toolchain;
  GitHub carries decisions/progress/PR context. This developer handoff is separate
  from the future product's cross-device synchronization ownership protocol.

Detailed requirements remain in [§4](../docs/product/master-spec.md#4-security-and-permission-model),
[§6](../docs/product/master-spec.md#6-high-level-architecture),
[§7](../docs/product/master-spec.md#7-google-calendar-synchronization),
[§8](../docs/product/master-spec.md#8-mcp-and-ai-integration), and
[§13](../docs/product/master-spec.md#13-public-repository-security).

## Unresolved decisions and deferred scope

This register owns open execution questions; write a linked ADR when resolved.
It does not imply that the corresponding feature is already implemented.

| Question / constraint | Owner / gate | Current disposition and closure evidence |
| --- | --- | --- |
| Practical deployment floor, sandbox/helper/process boundaries, background facilities | PR-02; refine in PR-05/15/17 | [ADR-0004](../docs/architecture/decisions/0004-platform-and-apple-apis.md) selects macOS 14; [0006](../docs/architecture/decisions/0006-local-mcp-and-processes.md)/[0007](../docs/architecture/decisions/0007-lifecycle-identity-and-distribution.md) select broker/stdio and opt-in login. Signed IPC, minimum-OS runtime and lifecycle evidence remain owning-PR gates. |
| Stable bundle/Keychain identity and signing/notarization strategy | PR-02, implemented in PR-08/30 | [ADR-0007](../docs/architecture/decisions/0007-lifecycle-identity-and-distribution.md): private broker Keychain, separate dev/prod identities, Developer ID strategy. Maintainer must confirm/register production ID before live authentication activation; signed continuity and release unverified. |
| Google desktop redirect/PKCE, app-created scope operations, verification/consent/quota/token behavior | PR-02/08/09 | [ADR-0005](../docs/architecture/decisions/0005-google-desktop-boundary.md): desktop PKCE/loopback and method scope audit. PR-08 owns console classification/consent; PR-09/16 must resolve private-calendar verification without ACL scope; PR-14 owns lost-ID recovery. PR-08/14/16 must disclose project-wide user-grant revocation versus local pause; PR-09/12 tests conditional writes and uncertain-insert recovery. Live proof remains required. |
| EventKit occurrence identity, exceptions, all-day/timezone/DST and rolling horizon | PR-02/03/07/11/13 | [ADR-0004](../docs/architecture/decisions/0004-platform-and-apple-apis.md): bounded materialization preferred, original recurrence anchor separate from mutable start, IDs not universal. Provider/resync/DST evidence remains PR-07/13; PR-03 models uncertainty. |
| Mapping/migration corruption recovery, multi-Mac active writer, ownership transfer | PR-10/12/14 | [ADR-0015](../docs/architecture/decisions/0015-sqlite-persistence.md) implements migrations and durable unknown-operation metadata. [ADR-0019](../docs/architecture/decisions/0019-deletion-safety-recovery.md) adds verified metadata recovery and cooperative writer transfer. Trusted live composition, backup/UI and actual two-Mac acceptance remain package 16 gates; a local file lock is not cross-device ownership. |
| Local MCP identity, pairing, revocation, proposal binding, replay/version protection | PR-02/17–21 | [ADR-0006](../docs/architecture/decisions/0006-local-mcp-and-processes.md): shipped-peer checks plus channel-bound local pairing, policy generations and exact approvals. [ADR-0024](../docs/architecture/decisions/0024-mcp-connection-identity.md) implements synthetic review/revocation; signed IPC/native review/current-OS integration remain engineering/maintainer gates after approved identity setup, before activation. [ADR-0025](../docs/architecture/decisions/0025-action-proposal-approval.md) implements local approval with mock writers; [ADR-0026](../docs/architecture/decisions/0026-calendar-mutation-journal.md) implements a gated EventKit adapter and durable restart containment; provider conflict, signed/native wiring and safe recovery acceptance remain required before real source mutation. |
| Contacts field selection, supported subsets and unified identity | PR-02/24/25 | [ADR-0004](../docs/architecture/decisions/0004-platform-and-apple-apis.md): minimal keys, application subsets, device-local/unified identity; no native macOS limited grant. Packages 24–25 implement synthetic read/subset/approval/journal evidence in ADR-0029/0030; signed provider and actual write acceptance remain open. |
| Notes accounts/folders, rich text/attachments/locked notes and CRUD reliability | PR-26/27 | [ADR-0031](../docs/architecture/decisions/0031-notes-feasibility.md) records the merged package 26 decision and merged package 27 availability follow-up: live Notes and the sandboxed synthetic prototype are deferred, not proven impossible. Engineering owns G1–G6; maintainer provides isolated fixture/signing setup and authorization. Revisit before activation or on new supported Apple APIs. Package 27 implements explicit deferral/availability only. |
| Secure remote MCP, tunnel/offline behavior, ChatGPT writes/plan eligibility | PR-28 | [ADR-0032](../docs/architecture/decisions/0032-remote-mcp-readiness.md) records an explicit activation deferral for review. Private authenticated tunnel candidate only; engineering owns R1–R6, maintainer owns approved identity/account/infrastructure setup. Revisit on isolated auth/signed-broker/client proof or platform change. No local-use cloud dependency. |
| Plugin publication and recurring-task compatibility, including original availability use case | PR-31 | [ADR-0035](../docs/architecture/decisions/0035-chatgpt-distribution.md) records the merged owned deferral. Engineering owns signed bridge, packaging and actual client/recurring proof; maintainer owns identity/eligibility/setup and publication decisions. Revisit on signed selected-read proof plus intended-client eligibility, or platform change. |
| Home-Mac setup and GitHub xcode-27 preview-runner availability | PR-01 workflow, ongoing | Home Mac unverified; toolchain/setup are documented. Keep exact baseline checks and record actual device/CI evidence. |
| Public security audit, distribution credentials, release/update/compatibility policy | PR-29/30 | Work package 29 records [scoped audit findings and owned gates](../docs/development/diagnostics-security-audit.md), with allowlisted diagnostics/export. Signed/provider acceptance, independent release review and distribution remain open; [ADR-0034](../docs/architecture/decisions/0034-release-engineering-readiness.md) implements development packaging and P1–P5 distribution gates; no signing credentials or production release established. |
| iCloud Drive, Photos, additional calendar/task providers, Microsoft 365 | Future, outside initial release | Deferred from initial commitment per spec §3.5; revisit via an explicit scoped proposal, without speculative permissions. |

No existing work package has been formally dropped. PR-02 merged in GitHub #3 at
`c96f4f0cbb54e2397d5c987a80cc2c0cd9ab0630`, verified 2026-10-26. Work package 03
merged in GitHub PR #4 at `a990e05721e75770df98ba01c2bad2bc5aa731a7`.
Work package 04 merged in GitHub PR #5 at `0cdac4bd5845b2b167a48c00332ef5ddf5080606`.
Work package 05 merged in GitHub PR #6 at `12b4ebf80816dcd307673a64085d00f88bb20981`.
Work package 06 merged in GitHub PR #7 at `ab345134daa94f4a4a195ae709e94d6f3d29c7e2`.
Work package 07 merged in GitHub PR #8 at `34c5c55019d805514117cb41c99adc5c67b1ba9a`; live Calendar acceptance remains open.
Work package 08 merged in GitHub PR #9 at `4d80fabae8b2b3a4482b582a48e974656a02eb3f`.
Work package 09 merged in GitHub PR #10 at `928732effe0985ed34a386cba4367ffd69bdc43c`.
Work package 10 [SQLite persistence](../docs/architecture/decisions/0015-sqlite-persistence.md)
merged in GitHub PR #11 at `4a5ad09a22be45b681c46675d756500603a58d8c`; the app never opens a store. Live OAuth, signed storage/networking,
destination privacy, trusted recovery integration and cross-Mac writer gates remain.
Work package 11 [pure planning](../docs/architecture/decisions/0016-pure-reconciliation-planner.md)
merged in GitHub PR #12 at `567b5a1a644c4b1ccba10eb21687c8d84d5c82cf`.
Work package 12 [durable execution](../docs/architecture/decisions/0017-synchronization-executor.md)
merged in GitHub PR #13 at `1d265050f0e12aa21847b26875e32e12c0d13f4b`.
Work package 13 merged in GitHub PR #14 at `554c4f2cc7914ae4b963f30b28cb529c94f1d3fe`.
Work package 14 implements [deletion safety and recovery](../docs/architecture/decisions/0019-deletion-safety-recovery.md)
merged in [GitHub PR #15](https://github.com/christianzbox/MacHandle/pull/15) at
`69a23b9c7a96b8ffc562400a4b9db7642eaf55d2`. Work package 15 implements
[background coordination](../docs/architecture/decisions/0020-background-synchronization.md)
merged in [GitHub PR #16](https://github.com/christianzbox/MacHandle/pull/16) at
`29f447b47948b054bc6266a946232bcc826d6881`. Work package 16 native onboarding and synthetic trusted orchestration merged in
[GitHub PR #17](https://github.com/christianzbox/MacHandle/pull/17) at
`4d1bc9467b9b827e61fbf493004f4d5ae525982a`. Its [owned activation follow-up](../docs/implementation/prs/pr-16.md#open-activation-follow-up--not-a-completed-milestone)
retains signed/live account, privacy, recovery/transfer and milestone B acceptance; no
requirement is silently dropped. Work package 17 merged in [GitHub PR #18](https://github.com/christianzbox/MacHandle/pull/18)
at `9bcc8b06113990f2002293981fe3f62b3d218092`. Work package 18 merged in GitHub PR #19 at
`defc08efb19028d4a9a5781c66b31748d217e9eb`. Work package 19 merged in GitHub PR #20 at
`77c3b797d403a5cfe957ac56d1b23f2c3462bea0`. Work package 20 merged in GitHub PR #21 at
`5dda18451154e0a72b2ecb47df851c8ebb4a306b`. Work package 21 merged in GitHub PR #22 at
`9b5f01ccacd449ae3e1b00e5f29c2672692679d1`. Its gated EventKit adapter/journal still requires signed/native,
provider conflict and live recovery acceptance under [ADR-0026](../docs/architecture/decisions/0026-calendar-mutation-journal.md).
Work package 22 merged in GitHub PR #23 with independent Reminders authorization, native selected-list reads and three
synthetic MCP read tools. [ADR-0027](../docs/architecture/decisions/0027-reminders-reads.md) retains
signed provider/runtime and MCP activation gates; Calendar/Google never confer Reminders access.
Package 23 merged in GitHub PR #24 at `03cdcb34173a4ecacb512fe10286a025efc10d60`.
Package 24 merged in GitHub PR #25 at `472981db82768cc6420c643e90e596f8ab805ccc`.
Packages 25–31 are merged; package 31 retains explicit activation deferral.
Notes retains its owned feasibility gates. Signed/provider and real-client acceptance remain open.
Actual limitations and any future deferral reason/revisit trigger are recorded in
[progress](../docs/implementation/progress.md).

## Per-PR lifecycle and context budget

**Product specification → master implementation plan → focused PR brief →
implementation → tests → review → merge → progress update.**

Start with [coordination](../docs/implementation/pr-coordination.md),
[progress](../docs/implementation/progress.md), and the relevant roadmap row/brief.
Read only that row's product sections, relevant architecture/ADRs, source, and tests;
do not reload all requirements or all future briefs for routine work. Inspect GitHub
state and prerequisites rather than treating this plan as a fresh repository audit.

Before opening/updating a PR, update its brief, roadmap state, progress/evidence,
coordination, and impacted architecture/ADRs. Run checks and record exact evidence
and limitations. Leave the PR open for user review, without auto-merge or publication.
After the user merges, the next authorized session verifies the GitHub merge SHA,
records it in progress/roadmap/coordination in its next PR, then selects eligible work.
Never mark an open PR Merged in anticipation or push bookkeeping directly to main.


Work package 23 merged with approved Reminder mutation contracts, with a dedicated durable journal,
native synthetic reviews and MCP propose/commit tools. [ADR-0028](../docs/architecture/decisions/0028-reminders-management.md)
keeps live activation closed on signed identity/native bridge/provider conflict and runtime evidence.
Recurring/alarm-bearing mutation support and list moves have explicit engineering-owned deferrals
until isolated fixtures justify exact effects/review scope; no product requirement silently disappears.
Package 24 implements independent Contacts reads under [ADR-0029](../docs/architecture/decisions/0029-contacts-reads.md). Package 25 implements independent Contacts approval/journal contracts under [ADR-0030](../docs/architecture/decisions/0030-contacts-management.md), with the live factory closed. Package 25 merged in GitHub PR #26 at `9704899f45b2a03c37e514a206f5b75d7c075122`. Package 26 merged in GitHub PR #27 at `4450809877cc553bfebc7bfa051ac269884e3865` with the Notes deferral decision under [ADR-0031](../docs/architecture/decisions/0031-notes-feasibility.md); its runtime proof remains an explicit deferred acceptance item. Package 27 merged in GitHub PR #28 at `c1012935d701224a46146bbed4a5f8850055e030`. Package 28 merged its explicit remote activation-deferral decision under [ADR-0032](../docs/architecture/decisions/0032-remote-mcp-readiness.md). Packages 29–30 are merged; package 30 squash is `5156700cdb8232720562207e10b1a1afa4807dc2`. Package 31 merged its distribution decision in GitHub PR #32. No milestone is released.

## After the original numbered sequence

The [activation backlog](../docs/implementation/activation-backlog.md) is a navigation index of
existing acceptance gates, not another master plan. Package 31 review/merge ends the numbered
sequence, not the remaining product implementation. Select one bounded follow-up with user
permission; do not invent an automatic package 32. Prefer signed local broker/pairing and isolated
selected-read acceptance before client packaging, with Notes feasibility and Google independent.
Retain all milestone and specification requirements until demonstrated or explicitly scoped out
of a particular release. No public release date is established. The bounded private-testing plan below defines the separately agreed follow-up estimate.

## Authorized native bridge follow-up — 2026-10-30

Package 31 merged in GitHub PR #32 at `34ad4c3e4e0165123cda48b9b3808adab8e7fd36`.
The user authorized a sample-only native bridge PR. The [focused follow-up](../docs/implementation/prs/native-bridge.md)
implements native pairing and a read broker with anonymous XPC fixture transport. This is bounded
progress on milestone C/D composition, not acceptance of signed external connectivity or live data.
[ADR-0036](../docs/architecture/decisions/0036-native-bridge-sample-pairing.md) retains the next signed
identity/discovery/peer and provider gates with engineering/maintainer owners. Personal iCloud remains
outside test scope. Stop after this review PR; do not begin another activation slice automatically.

## Reminders private testing finish line

Personal-use direction confirmed 2026-10-30: build MacHandle as a personal app for now. Public
release, monetization, company formation, Developer ID/notarization and paid Apple enrollment are
not prerequisites for this private finish line. Revisit them only if the maintainer later chooses
commercial/public distribution or a specific required capability demonstrably needs paid membership.
Engineering must document that concrete requirement before proposing a purchase. Keep employer
signing resources separate. This does not waive sandbox, peer identity, native consent or data safety;
first evaluate a suitable owner-controlled local signing/packaging route for personal use.

Agreed 2026-10-30: six planned slots, initially estimated as one focused review PR each. These are
not a new numbered product roadmap and do not promise completion of all deferred product features.
**Finish line:** on one designated Mac, one selected local desktop MCP client can discover and read
selected synthetic reminders and create/edit/complete/delete simple synthetic reminders through
MacHandle, with native approval for every write, durable recovery, and an isolated test runbook.
Personal iCloud stays outside this work. ChatGPT desktop is preferred; actual eligibility and
compatibility must be verified. No automatic fallback to another client without an explicit decision.

| Slot | Bounded outcome | Status / exit evidence |
| --- | --- | --- |
| 1 — External helper and identity | Independent helper reaches app-side broker through supported scoped IPC; mutual peer checks, native per-launch pairing, chosen desktop route | Two authorized PRs: GitHub PR #34 and #35 merged; [completion brief](../docs/implementation/prs/private-reminders-slot-1.md) records the sandboxed native sample app and real MCP relay verified on the current Mac. |
| 2 — Selected Reminders reads | Real public EventKit reads in a separately authorized isolated test environment; list/field grants and denied permissions | [Slot 2](../docs/implementation/prs/private-reminders-slot-2.md) merged in GitHub PR #36; real isolated EventKit/TCC acceptance remains open. No personal iCloud. |
| 3 — Approved simple writes | Create/edit/complete/delete, exact native review, precondition checks and durable journal | [Slot 3](../docs/implementation/prs/private-reminders-slot-3.md) sample implementation merged in GitHub PR #37. Atomic fixture effects only; live EventKit remains closed pending an accepted conflict contract and isolated acceptance. |
| 4 — Lifecycle and recovery | Disconnect/revoke, crashes/restarts, uncertain outcomes and safe recovery without replay | [Slot 4](../docs/implementation/prs/private-reminders-slot-4.md) merged in GitHub PR #38 at `99f0fda1d571425be6984b09637e513d0356d24a`; drain, recovery inspection and explicit fresh sessions. Uncertain records stay blocked. |
| 5 — Actual desktop client workflow | Install/configure one local client and prove supported MCP workflow, errors and approval round trips | [Slot 5](../docs/implementation/prs/private-reminders-slot-5.md) merged in GitHub PR #39 at `eb0002146b4efb5ae39c3f5e7131620c586fc102`; actual installed ChatGPT desktop local Codex sample workflow passed, including native approval/readbacks and negative cases. No public directory submission required. |
| 6 — Private test handoff | Reproducible private build/install, setup/permission instructions, isolation/cleanup and pass/fail checklist | [Slot 6](../docs/implementation/prs/private-reminders-slot-6.md) implemented for review: clean-source Release build, same-installation native restart and launcher cleanup passed on designated Mac; maintainer sample checklist pending. No in-place upgrade/migration. |

Excluded from this finish line: Notes, Google, Calendar/Contacts activation, remote access, scheduling,
recurring/alarm-bearing Reminder writes, list moves, multiple Macs, public distribution and App Store
review. Existing requirements remain in the activation index with their owners; these exclusions are
private-alpha scope, not deletion from the product specification.

Slots 1–5 sample implementation merged in GitHub PR #34–#39; #39 squash is
`eb0002146b4efb5ae39c3f5e7131620c586fc102`. Slot 6 is authorized for one private-testing handoff PR.
This is the final planned slot; the seven-PR estimate across six slots is unchanged. Stop
for slot 6 review, then maintainer sample-checklist acceptance. Real isolated read/write acceptance
remains gated; sample proof does not establish
EventKit/TCC/conflict semantics or resolve unknown live effects.

[ADR-0038](../docs/architecture/decisions/0038-private-native-mcp-relay.md) closes the missing native
sandbox/pairing/MCP path using a dedicated sample app and disposable local certificate on the current
Mac. This private target has no live provider dependency. The minimum macOS 14 target compiles; actual
minimum-OS runtime remains an engineering/maintainer compatibility gate before expanding machines or
claims. Actual selected desktop-client installation belongs to slot 5; stable private build identity
and upgrade handoff belong to slot 6. Its bounded policy preserves the same sealed build between sessions;
in-place upgrades/signing-key continuity and journal migration remain unsupported under
[ADR-0043](../docs/architecture/decisions/0043-private-test-installation.md). Historical slot 1 evidence
did not include these later installation checks. No paid enrollment is assumed. Full provider/TCC/public release gates remain.

Finish and review the slot 6 handoff PR, then stop. Scope/estimate a live-Reminders phase before any
further implementation. Live read/write acceptance remains gated
until engineering/maintainer resolve the EventKit conflict contract and separately authorize a verified
isolated macOS account with synthetic local lists. See
[ADR-0040](../docs/architecture/decisions/0040-private-approved-sample-writes.md). No personal iCloud,
TCC requests on the personal profile, merge, another implementation phase, persistent service, account creation or publication.
