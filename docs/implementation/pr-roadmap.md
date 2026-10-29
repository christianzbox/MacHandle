# PR roadmap

Detailed execution register under the [master implementation plan](../../plans/MacHandleMasterImplementationPlan.md).
All 31 original work packages are preserved. Their scope below is a routing summary;
the linked product requirements remain complete and authoritative. Each acceptance
statement is an observable gate, not a claim of present functionality.

## Work packages and GitHub PRs

Roadmap steps are **work packages**, numbered independently of GitHub's pull requests.
The original specification calls them PR-01, PR-02, etc.; those legacy IDs, brief
filenames and anchor links stay stable, but new prose/titles use work-package names.
A work package can have a different GitHub number; never infer one from the other.

| Work package | Change | GitHub review |
| --- | --- | --- |
| 01 | Repository foundation | [GitHub PR #1](https://github.com/christianzbox/MacHandle/pull/1), merged |
| 02 | Technical feasibility | [GitHub PR #3](https://github.com/christianzbox/MacHandle/pull/3), merged |
| 03 | Core domain models | [GitHub PR #4](https://github.com/christianzbox/MacHandle/pull/4), merged |
| 04 | Permission policy engine | [GitHub PR #5](https://github.com/christianzbox/MacHandle/pull/5), merged |
| 05 | Native application foundation | [GitHub PR #6](https://github.com/christianzbox/MacHandle/pull/6), merged |
| 06 | Calendar authorization/discovery | [GitHub PR #7](https://github.com/christianzbox/MacHandle/pull/7), merged |
| 07 | Calendar reads/availability | [GitHub PR #8](https://github.com/christianzbox/MacHandle/pull/8), merged |
| 08 | Google OAuth/Keychain | [GitHub PR #9 — Add Google OAuth and private Keychain credentials](https://github.com/christianzbox/MacHandle/pull/9), merged |
| 09 | Google destination client | [GitHub PR #10 — Add owned Google calendar destination operations](https://github.com/christianzbox/MacHandle/pull/10), merged |
| 10 | SQLite persistence | [GitHub PR #11 — Add versioned SQLite sync persistence](https://github.com/christianzbox/MacHandle/pull/11), merged |
| 11 | Pure reconciliation planner | [GitHub PR #12 — Add pure deterministic reconciliation planning](https://github.com/christianzbox/MacHandle/pull/12), merged |
| 12 | Synchronization executor | [GitHub PR #13 — Add durable synchronization execution and verified recovery](https://github.com/christianzbox/MacHandle/pull/13), merged |
| 13 | Recurrence, all-day and timezones | [GitHub PR #14 — Preserve recurrence identity and canonical calendar times](https://github.com/christianzbox/MacHandle/pull/14), merged |
| 14 | Deletion safety and recovery | [GitHub PR #15 — Add deletion safeguards and verified synchronization recovery](https://github.com/christianzbox/MacHandle/pull/15), merged |
| 15 | Background synchronization | [GitHub PR #16 — Add serialized background synchronization and opt-in login](https://github.com/christianzbox/MacHandle/pull/16), merged |
| 16 | Google onboarding and preferences | [GitHub PR #17 — Add reviewed Google sync onboarding and saved privacy preferences](https://github.com/christianzbox/MacHandle/pull/17), merged |
| 17 | MCP server foundation | [GitHub PR #18 — Add bounded synthetic MCP server and protocol compatibility](https://github.com/christianzbox/MacHandle/pull/18), merged |
| 18 | MCP Calendar reads | [GitHub PR #19 — Add policy-filtered MCP Calendar read operations](https://github.com/christianzbox/MacHandle/pull/19), merged |
| 19 | MCP connection identity and revocation | [GitHub PR #20](https://github.com/christianzbox/MacHandle/pull/20), merged |
| 20 | Action proposals and local approval | [GitHub PR #21](https://github.com/christianzbox/MacHandle/pull/21), merged |
| 21 | Journaled Calendar mutations | [GitHub PR #22](https://github.com/christianzbox/MacHandle/pull/22), merged |
| 22 | Reminders authorization and reads | [GitHub PR #23](https://github.com/christianzbox/MacHandle/pull/23), merged |
| 23 | Approved Reminders management | [GitHub PR #24](https://github.com/christianzbox/MacHandle/pull/24), merged |
| 24 | Contacts discovery and reads | [GitHub PR #25](https://github.com/christianzbox/MacHandle/pull/25), merged |
| 25 | Approved Contacts management | [GitHub PR #26](https://github.com/christianzbox/MacHandle/pull/26), merged |
| 26 | Notes feasibility decision | [GitHub PR #27](https://github.com/christianzbox/MacHandle/pull/27), merged |
| 27 | Notes experimental availability | [GitHub PR #28](https://github.com/christianzbox/MacHandle/pull/28), merged |
| 28 | Remote MCP readiness decision | Implemented on `codex/remote-mcp-readiness`; review PR pending |

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
  PR-02 is merged in GitHub #3 at `c96f4f0cbb54e2397d5c987a80cc2c0cd9ab0630`,
  2026-10-23 at 15:24:58 America/Detroit (19:24:58 UTC), rechecked 2026-10-26.
  Work package 03 merged in GitHub PR #4 at `a990e05721e75770df98ba01c2bad2bc5aa731a7`,
  2026-10-26 at 14:38:37 America/Detroit (18:38:37 UTC), rechecked before branching.
  Work package 04 merged in GitHub PR #5 at `0cdac4bd5845b2b167a48c00332ef5ddf5080606`,
  2026-10-26 14:57:29 America/Detroit (18:57:29 UTC), rechecked before branching.
  Work package 05 merged in GitHub PR #6 at `12b4ebf80816dcd307673a64085d00f88bb20981`,
  2026-10-26 15:18:26 America/Detroit (19:18:26 UTC), verified before branching.
  Work packages 06–08 are merged; package 08 squash is `4d80fabae8b2b3a4482b582a48e974656a02eb3f`.
  Work package 09 merged at `928732effe0985ed34a386cba4367ffd69bdc43c`.
  Work package 10 merged at `4a5ad09a22be45b681c46675d756500603a58d8c`.
  Work package 11 merged at `567b5a1a644c4b1ccba10eb21687c8d84d5c82cf`.
  Work package 12 merged at `1d265050f0e12aa21847b26875e32e12c0d13f4b`.
  Work package 13 merged at `554c4f2cc7914ae4b963f30b28cb529c94f1d3fe`.
  Work package 14 merged at `69a23b9c7a96b8ffc562400a4b9db7642eaf55d2`.
  Work packages 15–18 are merged. Package 18 squash is `defc08efb19028d4a9a5781c66b31748d217e9eb`,
  verified on GitHub 2026-10-28 at 19:03:57 UTC. Work package 19 merged in GitHub PR #20 at
  `77c3b797d403a5cfe957ac56d1b23f2c3462bea0` on 2026-10-28 19:26:07 UTC, verified before branching.
  Work package 20 merged in GitHub PR #21 at `5dda18451154e0a72b2ecb47df851c8ebb4a306b` on 2026-10-28 19:57:47 UTC.
  Work package 21 merged in GitHub PR #22 at `9b5f01ccacd449ae3e1b00e5f29c2672692679d1` on 2026-10-28 20:53:46 UTC.
  Work package 23 merged at `03cdcb34173a4ecacb512fe10286a025efc10d60`.
  Work package 24 merged at `472981db82768cc6420c643e90e596f8ab805ccc`.
  Work package 25 is active on `codex/authorized-contacts-management`; packages 26–31 remain planned or conditional.
  Research, model tests and compile evidence are separate from live acceptance.
- Dependencies must be verified merged. Default sequence is deliberately serial,
  not runtime dependency: Google and MCP remain independently usable. Reordering
  requires a documented plan/dependency update. No roadmap PR is formally deferred.

## Stage A — Project foundation

<a id="pr-01"></a>

### Work package 01

**Repository Foundation and Security**

- Dependencies: Existing main initialization.
- GitHub: [PR #1](https://github.com/christianzbox/MacHandle/pull/1); merge SHA: `4364fb79676de22d07cb6e5c01738481aad1f7d5` (2026-10-23).
- Review: [Requirement acceptance map](prs/pr-01.md#requirement-review--2026-10-23); remaining verification limits in [progress](progress.md).
- Delivery state: Merged; verification scope and historical checkpoints in [progress](progress.md).
- Scope: Repository/Xcode skeleton, complete source preservation, canonical docs, safe CI, portable work/home setup.
- Acceptance: Build and all checks pass; no private material tracked; independent clean clone works; complete linked docs and existing PR remain reviewable.
- Read: [Focused brief](prs/pr-01.md); [original PR requirements](../product/master-spec.md#pr-01--repository-foundation-and-security); [§13](../product/master-spec.md#13-public-repository-security), [§15](../product/master-spec.md#15-repository-structure), [§16](../product/master-spec.md#16-documentation-strategy), [§17](../product/master-spec.md#17-development-methodology), [§20](../product/master-spec.md#20-testing-strategy), [§21](../product/master-spec.md#21-cicd-and-release-safety), [§23](../product/master-spec.md#23-codex-context-management), [§27](../product/master-spec.md#27-immediate-execution-instructions).

<a id="pr-02"></a>

### Work package 02

**Technical Feasibility and Architecture Decisions**

- Dependencies: [Work package 01](#pr-01), verified merged on GitHub.
- Delivery state: Merged documentation in [GitHub #3](https://github.com/christianzbox/MacHandle/pull/3), squash SHA `c96f4f0cbb54e2397d5c987a80cc2c0cd9ab0630` (2026-10-23). Live gates remain open.
- Scope: Deployment/toolchain, EventKit/Reminders/Contacts, Google scopes/OAuth, MCP, sandbox, background and signing feasibility ADRs; small synthetic probes.
- Acceptance: Supported decisions, alternatives, experiments and unresolved blockers recorded; no full feature implementation. [Requirement review](prs/pr-02.md#requirement-review--2026-10-23) records corrected gaps and remaining evidence limits.
- Read: [Focused brief](prs/pr-02.md); [original PR requirements](../product/master-spec.md#pr-02--technical-feasibility-and-architecture-decisions); [§4](../product/master-spec.md#4-security-and-permission-model), [§5](../product/master-spec.md#5-technology-stack), [§6](../product/master-spec.md#6-high-level-architecture), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§9](../product/master-spec.md#9-reminders-integration), [§10](../product/master-spec.md#10-contacts-integration), [§13](../product/master-spec.md#13-public-repository-security), [§21](../product/master-spec.md#21-cicd-and-release-safety).

<a id="pr-03"></a>

### Work package 03

**Core Resource and Domain Models**

- Dependencies: [Work package 02](#pr-02), verified merged on GitHub 2026-10-26.
- Delivery state: Merged in [GitHub PR #4](https://github.com/christianzbox/MacHandle/pull/4), squash SHA `a990e05721e75770df98ba01c2bad2bc5aa731a7` (2026-10-26). [Acceptance map](prs/pr-03.md#implementation-and-acceptance-map); exact validation/PR in [coordination](pr-coordination.md).
- Scope: Typed resources/connections, calendars/occurrences, reminders, contacts, availability, operations/proposals, errors/results.
- Acceptance: Domain models avoid infrastructure/UI dependencies; identities, intervals and error/completeness semantics have deterministic tests.
- Read: [Focused brief](prs/pr-03.md); [original PR requirements](../product/master-spec.md#pr-03--core-resource-and-domain-models); [§4](../product/master-spec.md#4-security-and-permission-model), [§6](../product/master-spec.md#6-high-level-architecture), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-04"></a>

### Work package 04

**Permission Policy Engine**

- Dependencies: [Work package 03](#pr-03), verified merged on GitHub.
- Delivery state: Merged in [GitHub PR #5](https://github.com/christianzbox/MacHandle/pull/5) at `0cdac4bd5845b2b167a48c00332ef5ddf5080606`. [Acceptance map](prs/pr-04.md#implementation-and-acceptance); current GitHub link/evidence in coordination.
- Scope: Per-connection selected-resource policies, operation/field grants, revocation, decisions and denial reasons.
- Acceptance: Default deny, field filtering, cross-connection isolation, privilege-escalation and revoked-access tests pass in isolation.
- Read: [Focused brief](prs/pr-04.md); [original PR requirements](../product/master-spec.md#pr-04--permission-policy-engine); [§4](../product/master-spec.md#4-security-and-permission-model), [§6](../product/master-spec.md#6-high-level-architecture), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-05"></a>

### Work package 05

**Native Application Foundation**

- Dependencies: [Work package 04](#pr-04), verified merged.
- Delivery state: Merged in [GitHub PR #6](https://github.com/christianzbox/MacHandle/pull/6) at `12b4ebf80816dcd307673a64085d00f88bb20981`. [Acceptance map](prs/pr-05.md#implementation-and-acceptance).
- Scope: Native SwiftUI app/menu bar, preferences/connections shells, design system, dependency composition, light/dark and mock states.
- Acceptance: Accessible mock UI and composition work without permissions or live-data claims; no unrelated provider implementation.
- Read: [Focused brief](prs/pr-05.md); [original PR requirements](../product/master-spec.md#pr-05--native-application-foundation); [§6](../product/master-spec.md#6-high-level-architecture), [§12](../product/master-spec.md#12-native-macos-experience), [§20](../product/master-spec.md#20-testing-strategy).

## Stage B — Calendars and Google

<a id="pr-06"></a>

### Work package 06

**Calendar Authorization and Discovery**

- Dependencies: [Work package 05](#pr-05), verified merged.
- Delivery state: Merged in [GitHub PR #7](https://github.com/christianzbox/MacHandle/pull/7) at `ab345134daa94f4a4a195ae709e94d6f3d29c7e2`. [Acceptance map](prs/pr-06.md#implementation-and-acceptance); live TCC/sandbox verification remains open.
- Scope: EventKit calendar authorization/discovery, account identity, calendar selection, denied/unavailable handling.
- Acceptance: Only user opt-in requests access; synthetic-account discovery and selection behave correctly; no event mutations.
- Read: [Focused brief](prs/pr-06.md); [original PR requirements](../product/master-spec.md#pr-06--calendar-authorization-and-discovery); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§13](../product/master-spec.md#13-public-repository-security).

<a id="pr-07"></a>

### Work package 07

**Calendar Reading and Availability**

- Dependencies: [Work package 06](#pr-06), verified merged.
- Delivery state: Merged in [GitHub PR #8](https://github.com/christianzbox/MacHandle/pull/8) at `34c5c55019d805514117cb41c99adc5c67b1ba9a`. [Acceptance map](prs/pr-07.md#implementation-and-acceptance); live provider/TCC gate remains open.
- Scope: Bounded calendar reads/search/details, availability, normalization, calendar filtering and validated source snapshots.
- Acceptance: Synthetic tests prove authorized filtering, availability privacy, boundaries and incomplete/unavailable distinctions; no source writes.
- Read: [Focused brief](prs/pr-07.md); [original PR requirements](../product/master-spec.md#pr-07--calendar-reading-and-availability); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-08"></a>

### Work package 08

**Google OAuth and Keychain**

- Dependencies: [Work package 07](#pr-07), verified merged.
- Delivery state: Merged in [GitHub PR #9](https://github.com/christianzbox/MacHandle/pull/9) at `4d80fabae8b2b3a4482b582a48e974656a02eb3f`. [Acceptance map](prs/pr-08.md#implementation-and-acceptance); live activation blocked on maintainer identity/console setup and signed verification.
- Scope: Desktop browser OAuth with PKCE/state/redirect validation; Keychain tokens, refresh, revocation/disconnect, auth tests.
- Acceptance: OAuth failures and refresh/revoke are tested; production consent/scope/token constraints and account/permission setup documented; no event writes or plaintext secrets.
- Read: [Focused brief](prs/pr-08.md); [original PR requirements](../product/master-spec.md#pr-08--google-oauth-and-keychain); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-09"></a>

### Work package 09

**Google Destination Client**

- Dependencies: [Work package 08](#pr-08), verified merged.
- Delivery state: Merged in [GitHub PR #10](https://github.com/christianzbox/MacHandle/pull/10) at `928732effe0985ed34a386cba4367ffd69bdc43c`; live activation/privacy/integration gates remain open.
- Scope: Narrow-scope Google client, private app-created destination ownership, event CRUD primitives, pagination/rate limits/errors.
- Acceptance: Operations stay within the owned destination; no unrelated-calendar or sharing changes; paginated/incomplete/error cases tested.
- Read: [Focused brief](prs/pr-09.md); [original PR requirements](../product/master-spec.md#pr-09--google-destination-client); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-10"></a>

### Work package 10

**SQLite Persistence**

- Dependencies: [Work package 09](#pr-09), verified merged.
- Delivery state: Merged in [GitHub PR #11](https://github.com/christianzbox/MacHandle/pull/11) at `4a5ad09a22be45b681c46675d756500603a58d8c`; no app activation or live sync.
- Scope: SQLite schema and migrations; resource/event mappings, fingerprints, sync state, pending operations/checkpoints.
- Acceptance: Migration, interrupted-state and corruption behavior is tested; no secrets in plaintext state and no destructive interpretation of lost data.
- Read: [Focused brief](prs/pr-10.md); [original PR requirements](../product/master-spec.md#pr-10--sqlite-persistence); [§6](../product/master-spec.md#6-high-level-architecture), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy), [§22](../product/master-spec.md#22-long-term-maintenance).

<a id="pr-11"></a>

### Work package 11

**Pure Reconciliation Planner**

- Dependencies: [Work package 10](#pr-10), verified merged.
- Delivery state: Merged in [GitHub PR #12](https://github.com/christianzbox/MacHandle/pull/12) at `567b5a1a644c4b1ccba10eb21687c8d84d5c82cf`; pure comparison only.
- Scope: Pure deterministic planning from complete source/destination snapshots, mappings and privacy into create/update/delete/no-op/conflict.
- Acceptance: Stable repeated inputs yield no unnecessary work; privacy reduction and incomplete snapshots are safe; no remote calls.
- Read: [Focused brief](prs/pr-11.md); [original PR requirements](../product/master-spec.md#pr-11--pure-reconciliation-planner); [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-12"></a>

### Work package 12

**Synchronization Executor**

- Dependencies: [Work package 11](#pr-11), verified merged.
- Delivery state: Merged in [GitHub PR #13](https://github.com/christianzbox/MacHandle/pull/13) at `1d265050f0e12aa21847b26875e32e12c0d13f4b`; live activation denied.
- Scope: Ordered executor with checkpoints, partial-failure/retry safety, remote verification, interrupted-write recovery.
- Acceptance: Synthetic remote failures/retries recover without duplicate effects or false success; original EventKit calendars are never written.
- Read: [Focused brief](prs/pr-12.md); [original PR requirements](../product/master-spec.md#pr-12--synchronization-executor); [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-13"></a>

### Work package 13

**Recurrence, All-Day, and Timezone Correctness**

- Dependencies: [Work package 12](#pr-12), verified merged.
- Delivery state: Merged in [GitHub PR #14](https://github.com/christianzbox/MacHandle/pull/14) at `554c4f2cc7914ae4b963f30b28cb529c94f1d3fe`; live provider gates open.
- Scope: Recurring series/occurrence exceptions/cancellations, all-day boundaries, timezones/DST and rolling horizon.
- Acceptance: Synthetic recurrence, moves, exceptions and time-boundary cases retain correct identity and avoid duplicate/deleted valid occurrences.
- Read: [Focused brief](prs/pr-13.md); [original PR requirements](../product/master-spec.md#pr-13--recurrence-all-day-and-timezone-correctness); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-14"></a>

### Work package 14

**Deletion Safety and Recovery**

- Dependencies: [Work package 13](#pr-13), verified merged.
- Delivery state: Merged in [GitHub PR #15](https://github.com/christianzbox/MacHandle/pull/15) at `69a23b9c7a96b8ffc562400a4b9db7642eaf55d2`; [acceptance](prs/pr-14.md#implementation-and-acceptance), live gates open.
- Scope: Incomplete-source and mass-deletion guards, lost mapping/destination reconstruction, account migration, one active writer/standby.
- Acceptance: Failure injection proves unavailable/revoked/corrupt reads cannot delete; safe device transfer/recovery is demonstrated.
- Read: [Focused brief](prs/pr-14.md); [original PR requirements](../product/master-spec.md#pr-14--deletion-safety-and-recovery); [§4](../product/master-spec.md#4-security-and-permission-model), [§7](../product/master-spec.md#7-google-calendar-synchronization), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-15"></a>

### Work package 15

**Background Synchronization**

- Dependencies: [Work package 14](#pr-14), verified merged.
- Delivery state: Merged in [GitHub PR #16](https://github.com/christianzbox/MacHandle/pull/16) at `29f447b47948b054bc6266a946232bcc826d6881`; [acceptance](prs/pr-15.md#implementation-and-acceptance), live gates open.
- Scope: Launch at login, scheduling/change notifications, debouncing, sleep/wake/network recovery, pause/resume and exclusion of overlap.
- Acceptance: Lifecycle/retry tests pass; idle resource usage measured; no overlapping jobs or claim of operation while Mac is off.
- Read: [Focused brief](prs/pr-15.md); [original PR requirements](../product/master-spec.md#pr-15--background-synchronization); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§12](../product/master-spec.md#12-native-macos-experience), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-16"></a>

### Work package 16

**Google Sync Onboarding and Preferences**

- Dependencies: [Work package 15](#pr-15), verified merged.
- Delivery state: Merged in [GitHub PR #17](https://github.com/christianzbox/MacHandle/pull/17) at `4d1bc9467b9b827e61fbf493004f4d5ae525982a`; [acceptance and owned activation follow-up](prs/pr-16.md#implementation-and-acceptance). Live end-to-end acceptance and milestone B remain open.
- Scope: Native Google flow: source selection, sign-in, privacy, initial preview/confirmation, status/errors/settings/disconnect.
- Acceptance: Selected-source to private destination mirroring is proven end to end with synthetic isolated accounts; Google works without AI.
- Read: [Focused brief](prs/pr-16.md); [original PR requirements](../product/master-spec.md#pr-16--google-sync-onboarding-and-preferences); [§7](../product/master-spec.md#7-google-calendar-synchronization), [§12](../product/master-spec.md#12-native-macos-experience), [§20](../product/master-spec.md#20-testing-strategy), [§25](../product/master-spec.md#25-final-product-acceptance-criteria).

## Stage C — Local MCP

<a id="pr-17"></a>

### Work package 17

**MCP Server Foundation**

- Dependencies: [Work package 16](#pr-16), verified merged.
- Delivery state: Merged in [GitHub PR #18](https://github.com/christianzbox/MacHandle/pull/18) at `9bcc8b06113990f2002293981fe3f62b3d218092`; [acceptance](prs/pr-17.md#implementation-and-acceptance). Signed broker/live activation remains gated.
- Scope: MCP stdio lifecycle/version compatibility, typed tool registration/schemas/errors, adapter boundary and mock tools; use [ADR-0006](../architecture/decisions/0006-local-mcp-and-processes.md) to distinguish current per-request metadata from legacy initialization.
- Acceptance: Protocol tests/interoperability cover initialization/error behavior; no live personal data exposed and no stdio-as-identity assumption.
- Read: [Focused brief](prs/pr-17.md); [original PR requirements](../product/master-spec.md#pr-17--mcp-server-foundation); [§4](../product/master-spec.md#4-security-and-permission-model), [§6](../product/master-spec.md#6-high-level-architecture), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-18"></a>

### Work package 18

**MCP Read Operations**

- Dependencies: [Work package 17](#pr-17), verified merged.
- Delivery state: Merged in [GitHub PR #19](https://github.com/christianzbox/MacHandle/pull/19) at `defc08efb19028d4a9a5781c66b31748d217e9eb`; [acceptance](prs/pr-18.md#implementation-and-acceptance). Live external access remains gated.
- Scope: Policy-enforced calendar discovery, availability, event search and detail reads.
- Acceptance: Unauthorized resources/fields are filtered in tests; no source writes; live external activation remains gated on PR-19 identity/revocation.
- Read: [Focused brief](prs/pr-18.md); [original PR requirements](../product/master-spec.md#pr-18--mcp-read-operations); [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-19"></a>

### Work package 19

**MCP Connection Authentication and Revocation**

- Dependencies: [Work package 18](#pr-18), verified merged.
- Delivery state: Merged in [GitHub PR #20](https://github.com/christianzbox/MacHandle/pull/20) at `77c3b797d403a5cfe957ac56d1b23f2c3462bea0`; [acceptance](prs/pr-19.md#implementation-and-acceptance). Synthetic peers only; signed authentication/native pairing remain gated.
- Scope: Local identity/pairing/configuration, persisted per-connection policy, revocation/session invalidation and audit metadata.
- Acceptance: Caller impersonation, disabled/unauthorized clients and revoked sessions are rejected; PR-18 reads can be enabled only behind this boundary.
- Read: [Focused brief](prs/pr-19.md); [original PR requirements](../product/master-spec.md#pr-19--mcp-connection-authentication-and-revocation); [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-20"></a>

### Work package 20

**Safe Action Proposal and Approval Engine**

- Dependencies: [Work package 19](#pr-19), verified merged.
- Delivery state: Merged in [GitHub PR #21](https://github.com/christianzbox/MacHandle/pull/21) at `5dda18451154e0a72b2ecb47df851c8ebb4a306b`; [acceptance](prs/pr-20.md#implementation-and-acceptance). Mock writers and native sample review only; real writes remain gated.
- Scope: Create/update/delete proposals, exact diffs, local confirmation, expiring single-use approval tokens, audit records; mock writers.
- Acceptance: Replay, altered arguments/identity/target, expiration and revoked approval fail; execution is bound to the approved operation.
- Read: [Focused brief](prs/pr-20.md); [original PR requirements](../product/master-spec.md#pr-20--safe-action-proposal-and-approval-engine); [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-21"></a>

### Work package 21

**Authorized Calendar Mutations**

- Dependencies: [Work package 20](#pr-20), verified merged.
- Delivery state: Merged in [GitHub PR #22](https://github.com/christianzbox/MacHandle/pull/22) at `9b5f01ccacd449ae3e1b00e5f29c2672692679d1`; [acceptance](prs/pr-21.md#implementation-and-acceptance). Production factory denies; live EventKit conflict, recurrence, recovery and signed/native acceptance remain open.
- Scope: Real EventKit create/update/delete through the approved operations layer, target validation and version/conflict checks.
- Acceptance: Synthetic calendars demonstrate approved mutations and rejected conflicts/unauthorized requests; sync cannot acquire write capabilities.
- Read: [Focused brief](prs/pr-21.md); [original PR requirements](../product/master-spec.md#pr-21--authorized-calendar-mutations); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§20](../product/master-spec.md#20-testing-strategy).

## Stage D — Reminders

<a id="pr-22"></a>

### Work package 22

**Reminders Provider and Read Operations**

- Dependencies: [Work package 21](#pr-21), verified merged.
- Delivery state: Merged in [GitHub PR #23](https://github.com/christianzbox/MacHandle/pull/23) at `1e09e40b92dcc9a1f18ab287e535e3f8f0d1c649`; [acceptance](prs/pr-22.md#implementation-and-acceptance). Native explicit opt-in reads and synthetic MCP tools; signed/runtime acceptance remains open.
- Scope: Independent Reminders permission/provider, selected list discovery/search/details, policy and MCP read integration.
- Acceptance: No Calendar-derived authorization; selected-list isolation, denied/revoked access and read behavior tested with synthetic lists.
- Read: [Focused brief](prs/pr-22.md); [original PR requirements](../product/master-spec.md#pr-22--reminders-provider-and-read-operations); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§9](../product/master-spec.md#9-reminders-integration), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-23"></a>

### Work package 23

**Authorized Reminders Management**

- Dependencies: [Work package 22](#pr-22), verified merged.
- Delivery state: Merged in [GitHub PR #24](https://github.com/christianzbox/MacHandle/pull/24) at `03cdcb34173a4ecacb512fe10286a025efc10d60`; [acceptance](prs/pr-23.md#implementation-and-acceptance). Synthetic approved writes and gated EventKit backend; live activation denied.
- Scope: Approved reminder creation/update/completion/uncompletion/deletion, due dates/recurrence and MCP mutation tools.
- Acceptance: Synthetic-list writes respect policy/approval/versioning; due dates remain distinct from alarms; no implicit Google Tasks sync.
- Read: [Focused brief](prs/pr-23.md); [original PR requirements](../product/master-spec.md#pr-23--authorized-reminders-management); [§4](../product/master-spec.md#4-security-and-permission-model), [§9](../product/master-spec.md#9-reminders-integration), [§20](../product/master-spec.md#20-testing-strategy).

## Stage E — Contacts and Notes

<a id="pr-24"></a>

### Work package 24

**Contacts Discovery and Read Operations**

- Dependencies: [Work package 23](#pr-23).
- Delivery state: Merged in [GitHub PR #25](https://github.com/christianzbox/MacHandle/pull/25) at `472981db82768cc6420c643e90e596f8ab805ccc`; [acceptance](prs/pr-24.md#implementation-and-acceptance). Signed/runtime and live MCP gates remain open.
- Scope: Contacts authorization, field-minimized search/details, supported container/subset policies and MCP reads.
- Acceptance: Synthetic contacts prove minimum fields, per-connection filtering and unified/container identity behavior; no automatic export.
- Read: [Focused brief](prs/pr-24.md); [original PR requirements](../product/master-spec.md#pr-24--contacts-discovery-and-read-operations); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§10](../product/master-spec.md#10-contacts-integration), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-25"></a>

### Work package 25

**Authorized Contacts Management**

- Dependencies: [Work package 24](#pr-24).
- Delivery state: Merged in [GitHub PR #26](https://github.com/christianzbox/MacHandle/pull/26) at `9704899f45b2a03c37e514a206f5b75d7c075122`; [acceptance](prs/pr-25.md#implementation-and-acceptance). Live writes remain gated.
- Scope: Approved contact creation, selected-field updates/deletion, conflicts and redacted audits with heightened deletion safeguards.
- Acceptance: Synthetic tests reject unauthorized fields/stale writes and require proper deletion approval; unrelated contacts remain unchanged.
- Read: [Focused brief](prs/pr-25.md); [original PR requirements](../product/master-spec.md#pr-25--authorized-contacts-management); [§4](../product/master-spec.md#4-security-and-permission-model), [§10](../product/master-spec.md#10-contacts-integration), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-26"></a>

### Work package 26

**Apple Notes Feasibility and Security Review**

- Dependencies: [Work package 25](#pr-25).
- Delivery state: Decision merged in [GitHub PR #27](https://github.com/christianzbox/MacHandle/pull/27) at `4450809877cc553bfebc7bfa051ac269884e3865`; [acceptance](prs/pr-26.md#implementation-and-acceptance). Live Notes activation and the sandboxed synthetic prototype are explicitly deferred with owners/triggers in [ADR-0031](../architecture/decisions/0031-notes-feasibility.md).
- Scope: Mandatory supported Notes feasibility: AppleScript/Shortcuts, Automation/sandbox, fidelity/identity, locked notes/attachments and CRUD limits.
- Acceptance: Synthetic proof and ADR state safe supported capabilities or reasons to defer; no private framework/database bypass.
- Read: [Focused brief](prs/pr-26.md); [original PR requirements](../product/master-spec.md#pr-26--apple-notes-feasibility-and-security-review); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§11](../product/master-spec.md#11-notes-integration), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-27"></a>

### Work package 27

**Optional Notes Integration**

- Dependencies: [Work package 26](#pr-26) feasibility decision merged; safe support or explicit deferral.
- Delivery state: Explicit deferral/availability merged in [GitHub PR #28](https://github.com/christianzbox/MacHandle/pull/28) at `c1012935d701224a46146bbed4a5f8850055e030`; [acceptance](prs/pr-27.md#implementation-and-acceptance). No live Notes capability approved; isolated runtime proof remains deferred.
- Scope: Only PR-26-approved Notes capabilities, or a documented explicit deferral if feasibility fails.
- Acceptance: Claim only demonstrated, enforceable read/write subsets; unsafe or unsupported capabilities have a reason and revisit trigger.
- Read: [Focused brief](prs/pr-27.md); [original PR requirements](../product/master-spec.md#pr-27--optional-notes-integration); [§3](../product/master-spec.md#3-product-scope), [§4](../product/master-spec.md#4-security-and-permission-model), [§11](../product/master-spec.md#11-notes-integration), [§20](../product/master-spec.md#20-testing-strategy).

## Stage F — Remote integrations, polish, and release

<a id="pr-28"></a>

### Work package 28

**Remote MCP Compatibility and Secure Connection**

- Dependencies: [Work package 25](#pr-25), [Work package 26](#pr-26), and [Work package 27](#pr-27) implementation/deferral decision merged.
- Delivery state: Decision and availability notice implemented for review on `codex/remote-mcp-readiness`; [acceptance](prs/pr-28.md#implementation-and-acceptance). Activation explicitly deferred with engineering/maintainer owners and R1–R6 triggers in [ADR-0032](../architecture/decisions/0032-remote-mcp-readiness.md).
- Scope: Secure remote transport/authentication/authorization, TLS/origin/tunnel/revocation/offline behavior and ChatGPT compatibility.
- Acceptance: Verified supported secure connection or explicit activation deferral; no unauthenticated endpoint or mandatory local-use cloud backend.
- Read: [Focused brief](prs/pr-28.md); [original PR requirements](../product/master-spec.md#pr-28--remote-mcp-compatibility-and-secure-connection); [§4](../product/master-spec.md#4-security-and-permission-model), [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy).

<a id="pr-29"></a>

### Work package 29

**Diagnostics, UX Hardening, and Security Audit**

- Dependencies: [Work package 28](#pr-28) secure implementation or documented activation-deferral decision merged.
- Delivery state: Planned.
- Scope: Connections dashboard, sync/audit diagnostics, redacted support export, accessibility/error recovery, profiling and security review.
- Acceptance: Supported services have end-to-end evidence; sensitive exports minimized, recovery/accessibility checked, audit findings resolved or gated.
- Read: [Focused brief](prs/pr-29.md); [original PR requirements](../product/master-spec.md#pr-29--diagnostics-ux-hardening-and-security-audit); [§12](../product/master-spec.md#12-native-macos-experience), [§13](../product/master-spec.md#13-public-repository-security), [§20](../product/master-spec.md#20-testing-strategy), [§25](../product/master-spec.md#25-final-product-acceptance-criteria).

<a id="pr-30"></a>

### Work package 30

**Public Release Engineering**

- Dependencies: [Work package 29](#pr-29).
- Delivery state: Planned.
- Scope: Developer ID signing/notarization/hardened runtime, packaging/checksums/GitHub Releases, installation/update/privacy/security policy.
- Acceptance: Validate distribution artifacts and advertised features with required credentials; no public release until gates pass and user authorizes it.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-30--public-release-engineering); [§13](../product/master-spec.md#13-public-repository-security), [§19](../product/master-spec.md#19-release-milestones), [§21](../product/master-spec.md#21-cicd-and-release-safety), [§22](../product/master-spec.md#22-long-term-maintenance), [§25](../product/master-spec.md#25-final-product-acceptance-criteria).

<a id="pr-31"></a>

### Work package 31

**ChatGPT Plugin Packaging and Distribution**

- Dependencies: [Work package 30](#pr-30); supported remote capability for any remote claims.
- Delivery state: Conditional planned; decision gate unresolved.
- Scope: Supported ChatGPT plugin packaging/distribution, eligibility, local/remote boundaries, review, writes, setup, permissions and scheduling.
- Acceptance: Actual compatibility and approval evidence or explicit external-platform deferral; original scheduled availability use case independently verified.
- Read: Create the focused brief after prerequisite evidence; [original PR requirements](../product/master-spec.md#pr-31--chatgpt-plugin-packaging-and-distribution); [§8](../product/master-spec.md#8-mcp-and-ai-integration), [§19](../product/master-spec.md#19-release-milestones), [§25](../product/master-spec.md#25-final-product-acceptance-criteria).

## Next handoff

Package 17 merged in GitHub PR #18. Review package 18 on its linked branch/PR;
do not start package 19 without verified merge and explicit authorization.
The [brief index](prs/README.md) includes the next focused brief; future briefs are created
incrementally, not fabricated as if future architectural decisions were settled.
For every PR update this register, progress, coordination, the active/next brief,
and affected architecture/ADRs. After user merge, record verified merge evidence
in the next authorized PR, without an autonomous merge or direct push to main.
