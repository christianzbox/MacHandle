# MacHandle — Master Implementation Plan

Status: authoritative execution roadmap. Updated: 2026-10-27.

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
| Local MCP identity, pairing, revocation, proposal binding, replay/version protection | PR-02/17–21 | [ADR-0006](../docs/architecture/decisions/0006-local-mcp-and-processes.md): shipped-peer checks plus channel-bound local pairing, policy generations and exact approvals. Signed IPC/client-version matrix PR-17; activation blocked until PR-19; write gates PR-20/21. |
| Contacts field selection, supported subsets and unified identity | PR-02/24/25 | [ADR-0004](../docs/architecture/decisions/0004-platform-and-apple-apis.md): minimal keys, application subsets, device-local/unified identity; no native macOS limited grant. PR-24/25 retains synthetic subset/write evidence gate. |
| Notes accounts/folders, rich text/attachments/locked notes and CRUD reliability | PR-26/27 | Conditional planned. Mandatory feasibility gate; defer capabilities that cannot be safely enforced. No deferral verdict yet. |
| Secure remote MCP, tunnel/offline behavior, ChatGPT writes/plan eligibility | PR-28 | Conditional planned. Defer activation if safe support needs unapproved infrastructure/platform capabilities. |
| Plugin publication and recurring-task compatibility, including original availability use case | PR-31 | Conditional planned. Verify current platform behavior/review and scheduled tasks independently; do not claim approval early. |
| Home-Mac setup and GitHub xcode-27 preview-runner availability | PR-01 workflow, ongoing | Home Mac unverified; toolchain/setup are documented. Keep exact baseline checks and record actual device/CI evidence. |
| Public security audit, distribution credentials, release/update/compatibility policy | PR-29/30 | Planned release gates; no signing credentials or production release currently established. |
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
for review in [GitHub PR #16](https://github.com/christianzbox/MacHandle/pull/16); live sync remains denied. Packages 16–31 remain Planned or Conditional in the roadmap.
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
