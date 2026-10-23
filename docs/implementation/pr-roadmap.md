# PR roadmap

Detailed execution register under the [master implementation plan](../../plans/MacHandleMasterImplementationPlan.md).
All 31 original work packages are preserved. Their scope below is a routing summary;
the linked product requirements remain complete and authoritative. Each acceptance
statement is an observable gate, not a claim of present functionality.

## Status and dependency rules

- **Planned:** scope is recorded; no implementation claim. **Conditional planned:**
  future work requires a specific feasibility/platform decision, not a deferral verdict.
- **In progress:** active unfinished work. **Implemented:** code/docs exist on a named
  branch; this does not imply tests, review, merge, or release.
- **Verified:** separate evidence dimension, limited to named tests/toolchain/commit.
  **Merged:** separate GitHub fact requiring the merge SHA. **Deferred:** explicit
  decision with reason and revisit trigger; preserve the requirement.
- [Progress](progress.md) owns evidence/limitations; [coordination](pr-coordination.md)
  owns active branches, PR links and merge checkpoints. Use them with this register.
- PR-01 is merged: GitHub #1, squash SHA `4364fb79676de22d07cb6e5c01738481aad1f7d5`,
  2026-10-23 at 14:14:32 America/Detroit (18:14:32 UTC), rechecked in PR-02.
  PR-02 is active on `codex/pr-02-technical-feasibility`; researched decisions and
  compile evidence are separate from live acceptance. PR-03–31 remain planned.
- Dependencies must be verified merged. Default sequence is deliberately serial,
  not runtime dependency: Google and MCP remain independently usable. Reordering
  requires a documented plan/dependency update. No roadmap PR is formally deferred.

## Stage A — Project foundation

### PR-01

**Repository Foundation and Security**

- Dependencies: Existing main initialization.
- GitHub: [PR #1](https://github.com/christianzbox/MacHandle/pull/1); merge SHA: `4364fb79676de22d07cb6e5c01738481aad1f7d5` (2026-10-23).
- Review: [Requirement acceptance map](prs/pr-01.md#requirement-review--2026-10-23); remaining verification limits in [progress](progress.md).
- Delivery state: Merged; verification scope and historical checkpoints in [progress](progress.md).
- Scope: Repository/Xcode skeleton, complete source preservation, canonical docs, safe CI, portable work/home setup.
- Acceptance: Build and all checks pass; no private material tracked; independent clean clone works; complete linked docs and existing PR remain reviewable.
- Read: [Focused brief](prs/pr-01.md); [original PR requirements](../product/master-spec.md#pr-01--repository-foundation-and-security); [§13](../product/master-spec.md#13-public-repository-security), [§15](../product/master-spec.md#15-repository-structure), [§16](../product/master-spec.md#16-documentation-strategy), [§17](../product/master-spec.md#17-development-methodology), [§20](../product/master-spec.md#20-testing-strategy), [§21](../product/master-spec.md#21-cicd-and-release-safety), [§23](../product/master-spec.md#23-codex-context-management), [§27](../product/master-spec.md#27-immediate-execution-instructions).

### PR-02

**Technical Feasibility and Architecture Decisions**

- Dependencies: [PR-01](#pr-01), verified merged on GitHub.
- Delivery state: Implemented documentation on `codex/pr-02-technical-feasibility`, [GitHub #3](https://github.com/christianzbox/MacHandle/pull/3); not merged. Review/validation tracked in [coordination](pr-coordination.md).
- Scope: Deployment/toolchain, EventKit/Reminders/Contacts, Google scopes/OAuth, MCP, sandbox, background and signing feasibility ADRs; small synthetic probes.
- Acceptance: Supported decisions, alternatives, experiments and unresolved blockers recorded; no full feature implementation.
- Read: [Focused brief](prs/pr-02.md); [original PR requirements](../product/master-spec.md#pr-02--technical-feasibility-and-architecture-decisions); [§4](../product/master-spec.md#4-security-and-permission-model), [§5](../product/master-spec.md#5-technology-stack), [§6](../product/master-spec.md#6-high-level-architecture), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§9](../product/master-spec.md#9-reminders-integration), [§10](../product/master-spec.md#10-contacts-integration), [§13](../product/master-spec.md#13-public-repository-security), [§21](../product/master-spec.md#21-cicd-and-release-safety).

### PR-03

**Core Resource and Domain Models**

- Dependencies: [PR-02](#pr-02).
- Delivery state: Planned.
- Scope: Typed resources/connections, calendars/occurrences, reminders, contacts, availability, operations/proposals, errors/results.
- Acceptance: Domain models avoid infrastructure/UI dependencies; identities, intervals and error/completeness semantics have deterministic tests.
- Read: [Focused brief](prs/pr-03.md); [original PR requirements](../product/master-spec.md#pr-03--core-resource-and-domain-models); [§4](../product/master-spec.md#4-security-and-permission-model), [§6](../product/master-spec.md#6-high-level-architecture), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

### PR-04

**Permission Policy Engine**

- Dependencies: [PR-03](#pr-03).
- Delivery state: Planned.
- Scope: Per-connection selected-resource policies, operation/field grants, revocation, decisions and denial reasons.
- Acceptance: Default deny, field filtering, cross-connection isolation, privilege-escalation and revoked-access tests pass in isolation.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-04--permission-policy-engine); [§4](../product/master-spec.md#4-security-and-permission-model), [§6](../product/master-spec.md#6-high-level-architecture), [§20](../product/master-spec.md#20-testing-strategy).

### PR-05

**Native Application Foundation**

- Dependencies: [PR-04](#pr-04).
- Delivery state: Planned.
- Scope: Native SwiftUI app/menu bar, preferences/connections shells, design system, dependency composition, light/dark and mock states.
- Acceptance: Accessible mock UI and composition work without permissions or live-data claims; no unrelated provider implementation.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-05--native-application-foundation); [§6](../product/master-spec.md#6-high-level-architecture), [§12](../product/master-spec.md#12-native-macos-experience), [§20](../product/master-spec.md#20-testing-strategy).

## Stage B — Calendars and Google

### PR-06

**Calendar Authorization and Discovery**

- Dependencies: [PR-05](#pr-05).
- Delivery state: Planned.
- Scope: EventKit calendar authorization/discovery, account identity, calendar selection, denied/unavailable handling.
- Acceptance: Only user opt-in requests access; synthetic-account discovery and selection behave correctly; no event mutations.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-06--calendar-authorization-and-discovery); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§13](../product/master-spec.md#13-public-repository-security).

### PR-07

**Calendar Reading and Availability**

- Dependencies: [PR-06](#pr-06).
- Delivery state: Planned.
- Scope: Bounded calendar reads/search/details, availability, normalization, calendar filtering and validated source snapshots.
- Acceptance: Synthetic tests prove authorized filtering, availability privacy, boundaries and incomplete/unavailable distinctions; no source writes.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-07--calendar-reading-and-availability); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

### PR-08

**Google OAuth and Keychain**

- Dependencies: [PR-07](#pr-07).
- Delivery state: Planned.
- Scope: Desktop browser OAuth with PKCE/state/redirect validation; Keychain tokens, refresh, revocation/disconnect, auth tests.
- Acceptance: OAuth failures and refresh/revoke are tested; production consent/scope/token constraints documented; no event writes or plaintext secrets.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-08--google-oauth-and-keychain); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

### PR-09

**Google Destination Client**

- Dependencies: [PR-08](#pr-08).
- Delivery state: Planned.
- Scope: Narrow-scope Google client, private app-created destination ownership, event CRUD primitives, pagination/rate limits/errors.
- Acceptance: Operations stay within the owned destination; no unrelated-calendar or sharing changes; paginated/incomplete/error cases tested.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-09--google-destination-client); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

### PR-10

**SQLite Persistence**

- Dependencies: [PR-09](#pr-09).
- Delivery state: Planned.
- Scope: SQLite schema and migrations; resource/event mappings, fingerprints, sync state, pending operations/checkpoints.
- Acceptance: Migration, interrupted-state and corruption behavior is tested; no secrets in plaintext state and no destructive interpretation of lost data.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-10--sqlite-persistence); [§6](../product/master-spec.md#6-high-level-architecture), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy), [§22](../product/master-spec.md#22-long-term-maintenance).

### PR-11

**Pure Reconciliation Planner**

- Dependencies: [PR-10](#pr-10).
- Delivery state: Planned.
- Scope: Pure deterministic planning from complete source/destination snapshots, mappings and privacy into create/update/delete/no-op/conflict.
- Acceptance: Stable repeated inputs yield no unnecessary work; privacy reduction and incomplete snapshots are safe; no remote calls.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-11--pure-reconciliation-planner); [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

### PR-12

**Synchronization Executor**

- Dependencies: [PR-11](#pr-11).
- Delivery state: Planned.
- Scope: Ordered executor with checkpoints, partial-failure/retry safety, remote verification, interrupted-write recovery.
- Acceptance: Synthetic remote failures/retries recover without duplicate effects or false success; original EventKit calendars are never written.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-12--synchronization-executor); [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

### PR-13

**Recurrence, All-Day, and Timezone Correctness**

- Dependencies: [PR-12](#pr-12).
- Delivery state: Planned.
- Scope: Recurring series/occurrence exceptions/cancellations, all-day boundaries, timezones/DST and rolling horizon.
- Acceptance: Synthetic recurrence, moves, exceptions and time-boundary cases retain correct identity and avoid duplicate/deleted valid occurrences.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-13--recurrence-all-day-and-timezone-correctness); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

### PR-14

**Deletion Safety and Recovery**

- Dependencies: [PR-13](#pr-13).
- Delivery state: Planned.
- Scope: Incomplete-source and mass-deletion guards, lost mapping/destination reconstruction, account migration, one active writer/standby.
- Acceptance: Failure injection proves unavailable/revoked/corrupt reads cannot delete; safe device transfer/recovery is demonstrated.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-14--deletion-safety-and-recovery); [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

### PR-15

**Background Synchronization**

- Dependencies: [PR-14](#pr-14).
- Delivery state: Planned.
- Scope: Launch at login, scheduling/change notifications, debouncing, sleep/wake/network recovery, pause/resume and exclusion of overlap.
- Acceptance: Lifecycle/retry tests pass; idle resource usage measured; no overlapping jobs or claim of operation while Mac is off.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-15--background-synchronization); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§12](../product/master-spec.md#12-native-macos-experience), [§20](../product/master-spec.md#20-testing-strategy).

### PR-16

**Google Sync Onboarding and Preferences**

- Dependencies: [PR-15](#pr-15).
- Delivery state: Planned.
- Scope: Native Google flow: source selection, sign-in, privacy, initial preview/confirmation, status/errors/settings/disconnect.
- Acceptance: Selected-source to private destination mirroring is proven end to end with synthetic isolated accounts; Google works without AI.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-16--google-sync-onboarding-and-preferences); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§12](../product/master-spec.md#12-native-macos-experience), [§20](../product/master-spec.md#20-testing-strategy), [§25](../product/master-spec.md#25-final-product-acceptance-criteria).

## Stage C — Local MCP

### PR-17

**MCP Server Foundation**

- Dependencies: [PR-16](#pr-16).
- Delivery state: Planned.
- Scope: MCP stdio lifecycle/version compatibility, typed tool registration/schemas/errors, adapter boundary and mock tools; use [ADR-0006](../architecture/decisions/0006-local-mcp-and-processes.md) to distinguish current per-request metadata from legacy initialization.
- Acceptance: Protocol tests/interoperability cover initialization/error behavior; no live personal data exposed and no stdio-as-identity assumption.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-17--mcp-server-foundation); [§4](../product/master-spec.md#4-security-and-permission-model), [§6](../product/master-spec.md#6-high-level-architecture), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§20](../product/master-spec.md#20-testing-strategy).

### PR-18

**MCP Read Operations**

- Dependencies: [PR-17](#pr-17).
- Delivery state: Planned.
- Scope: Policy-enforced calendar discovery, availability, event search and detail reads.
- Acceptance: Unauthorized resources/fields are filtered in tests; no source writes; live external activation remains gated on PR-19 identity/revocation.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-18--mcp-read-operations); [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§20](../product/master-spec.md#20-testing-strategy).

### PR-19

**MCP Connection Authentication and Revocation**

- Dependencies: [PR-18](#pr-18).
- Delivery state: Planned.
- Scope: Local identity/pairing/configuration, persisted per-connection policy, revocation/session invalidation and audit metadata.
- Acceptance: Caller impersonation, disabled/unauthorized clients and revoked sessions are rejected; PR-18 reads can be enabled only behind this boundary.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-19--mcp-connection-authentication-and-revocation); [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

### PR-20

**Safe Action Proposal and Approval Engine**

- Dependencies: [PR-19](#pr-19).
- Delivery state: Planned.
- Scope: Create/update/delete proposals, exact diffs, local confirmation, expiring single-use approval tokens, audit records; mock writers.
- Acceptance: Replay, altered arguments/identity/target, expiration and revoked approval fail; execution is bound to the approved operation.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-20--safe-action-proposal-and-approval-engine); [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§20](../product/master-spec.md#20-testing-strategy).

### PR-21

**Authorized Calendar Mutations**

- Dependencies: [PR-20](#pr-20).
- Delivery state: Planned.
- Scope: Real EventKit create/update/delete through the approved operations layer, target validation and version/conflict checks.
- Acceptance: Synthetic calendars demonstrate approved mutations and rejected conflicts/unauthorized requests; sync cannot acquire write capabilities.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-21--authorized-calendar-mutations); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§20](../product/master-spec.md#20-testing-strategy).

## Stage D — Reminders

### PR-22

**Reminders Provider and Read Operations**

- Dependencies: [PR-21](#pr-21).
- Delivery state: Planned.
- Scope: Independent Reminders permission/provider, selected list discovery/search/details, policy and MCP read integration.
- Acceptance: No Calendar-derived authorization; selected-list isolation, denied/revoked access and read behavior tested with synthetic lists.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-22--reminders-provider-and-read-operations); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§9](../product/master-spec.md#9-reminders-integration), [§20](../product/master-spec.md#20-testing-strategy).

### PR-23

**Authorized Reminders Management**

- Dependencies: [PR-22](#pr-22).
- Delivery state: Planned.
- Scope: Approved reminder creation/update/completion/uncompletion/deletion, due dates/recurrence and MCP mutation tools.
- Acceptance: Synthetic-list writes respect policy/approval/versioning; due dates remain distinct from alarms; no implicit Google Tasks sync.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-23--authorized-reminders-management); [§4](../product/master-spec.md#4-security-and-permission-model), [§9](../product/master-spec.md#9-reminders-integration), [§20](../product/master-spec.md#20-testing-strategy).

## Stage E — Contacts and Notes

### PR-24

**Contacts Discovery and Read Operations**

- Dependencies: [PR-23](#pr-23).
- Delivery state: Planned.
- Scope: Contacts authorization, field-minimized search/details, supported container/subset policies and MCP reads.
- Acceptance: Synthetic contacts prove minimum fields, per-connection filtering and unified/container identity behavior; no automatic export.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-24--contacts-discovery-and-read-operations); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§10](../product/master-spec.md#10-contacts-integration), [§20](../product/master-spec.md#20-testing-strategy).

### PR-25

**Authorized Contacts Management**

- Dependencies: [PR-24](#pr-24).
- Delivery state: Planned.
- Scope: Approved contact creation, selected-field updates/deletion, conflicts and redacted audits with heightened deletion safeguards.
- Acceptance: Synthetic tests reject unauthorized fields/stale writes and require proper deletion approval; unrelated contacts remain unchanged.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-25--authorized-contacts-management); [§4](../product/master-spec.md#4-security-and-permission-model), [§10](../product/master-spec.md#10-contacts-integration), [§20](../product/master-spec.md#20-testing-strategy).

### PR-26

**Apple Notes Feasibility and Security Review**

- Dependencies: [PR-25](#pr-25).
- Delivery state: Planned.
- Scope: Mandatory supported Notes feasibility: AppleScript/Shortcuts, Automation/sandbox, fidelity/identity, locked notes/attachments and CRUD limits.
- Acceptance: Synthetic proof and ADR state safe supported capabilities or reasons to defer; no private framework/database bypass.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-26--apple-notes-feasibility-and-security-review); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§11](../product/master-spec.md#11-notes-integration), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

### PR-27

**Optional Notes Integration**

- Dependencies: [PR-26](#pr-26) feasibility decision merged; safe support or explicit deferral.
- Delivery state: Conditional planned; decision gate unresolved.
- Scope: Only PR-26-approved Notes capabilities, or a documented explicit deferral if feasibility fails.
- Acceptance: Claim only demonstrated, enforceable read/write subsets; unsafe or unsupported capabilities have a reason and revisit trigger.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-27--optional-notes-integration); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§11](../product/master-spec.md#11-notes-integration), [§20](../product/master-spec.md#20-testing-strategy).

## Stage F — Remote integrations, polish, and release

### PR-28

**Remote MCP Compatibility and Secure Connection**

- Dependencies: [PR-25](#pr-25), [PR-26](#pr-26), and [PR-27](#pr-27) implementation/deferral decision merged.
- Delivery state: Conditional planned; decision gate unresolved.
- Scope: Secure remote transport/authentication/authorization, TLS/origin/tunnel/revocation/offline behavior and ChatGPT compatibility.
- Acceptance: Verified supported secure connection or explicit activation deferral; no unauthenticated endpoint or mandatory local-use cloud backend.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-28--remote-mcp-compatibility-and-secure-connection); [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

### PR-29

**Diagnostics, UX Hardening, and Security Audit**

- Dependencies: [PR-28](#pr-28) secure implementation or documented activation-deferral decision merged.
- Delivery state: Planned.
- Scope: Connections dashboard, sync/audit diagnostics, redacted support export, accessibility/error recovery, profiling and security review.
- Acceptance: Supported services have end-to-end evidence; sensitive exports minimized, recovery/accessibility checked, audit findings resolved or gated.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-29--diagnostics-ux-hardening-and-security-audit); [§12](../product/master-spec.md#12-native-macos-experience), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy), [§25](../product/master-spec.md#25-final-product-acceptance-criteria).

### PR-30

**Public Release Engineering**

- Dependencies: [PR-29](#pr-29).
- Delivery state: Planned.
- Scope: Developer ID signing/notarization/hardened runtime, packaging/checksums/GitHub Releases, installation/update/privacy/security policy.
- Acceptance: Validate distribution artifacts and advertised features with required credentials; no public release until gates pass and user authorizes it.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-30--public-release-engineering); [§13](../product/master-spec.md#13-public-repository-security), [§19](../product/master-spec.md#19-release-milestones), [§21](../product/master-spec.md#21-cicd-and-release-safety), [§22](../product/master-spec.md#22-long-term-maintenance), [§25](../product/master-spec.md#25-final-product-acceptance-criteria).

### PR-31

**ChatGPT Plugin Packaging and Distribution**

- Dependencies: [PR-30](#pr-30); supported remote capability for any remote claims.
- Delivery state: Conditional planned; decision gate unresolved.
- Scope: Supported ChatGPT plugin packaging/distribution, eligibility, local/remote boundaries, review, writes, setup, permissions and scheduling.
- Acceptance: Actual compatibility and approval evidence or explicit external-platform deferral; original scheduled availability use case independently verified.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-31--chatgpt-plugin-packaging-and-distribution); [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§19](../product/master-spec.md#19-release-milestones), [§25](../product/master-spec.md#25-final-product-acceptance-criteria).

## Next handoff

PR-01 merge is verified. Finish PR-02 review on its existing branch; do not begin
PR-03 until PR-02 is merged and the user authorizes that work.
The initial [brief index](prs/README.md) contains PR-01–03; future briefs are created
incrementally, not fabricated as if future architectural decisions were settled.
For every PR update this register, progress, coordination, the active/next brief,
and affected architecture/ADRs. After user merge, record verified merge evidence
in the next authorized PR, without an autonomous merge or direct push to main.
