# Architecture decision records

| Record | Status | Decision boundary |
| --- | --- | --- |
| [0001 Native foundation](0001-foundation.md) | Accepted; toolchain superseded by 0002, deployment by 0004 | SwiftUI/Xcode + local SwiftPM, initial app target and development bundle identity, sandbox configuration, alternatives to project generation. |
| [0002 Interchangeable Macs](0002-portable-development.md) | Accepted | Exact shared toolchain, per-process selection, clean-clone evidence, GitHub handoff; runner availability and home-Mac verification limits. |
| [0003 Documentation authority](0003-documentation-authority.md) | Accepted | Complete source preservation, one execution plan, evidence/coordination split, focused context and post-merge updates. |
| [0004 Platform and Apple APIs](0004-platform-and-apple-apis.md) | PR-02 design; runtime gates open | macOS 14 API baseline, OS versus application permissions, recurrence/completeness and Contacts constraints. |
| [0005 Google desktop boundary](0005-google-desktop-boundary.md) | PR-02 design; live/console gates open | Desktop PKCE/loopback, method-by-method narrow scope audit, privacy and recovery blockers. |
| [0006 Local MCP and processes](0006-local-mcp-and-processes.md) | PR-02 design; signed IPC/pairing gates open | Stdio versions, broker authority, external-helper sandbox limits, peer identity and revocation. |
| [0007 Lifecycle, identity and distribution](0007-lifecycle-identity-and-distribution.md) | PR-02 strategy; production identity unallocated | Opt-in login, scheduling limits, Keychain identity/accessibility and Developer ID/notarization gates. |
| [0008 Core domain contracts](0008-core-domain-contracts.md) | Work package 03 merged in GitHub PR #4 | Typed identity/time/fields, explicit observation uncertainty, exact proposals and independent read/write interfaces; no runtime authority. |
| [0009 Permission policy engine](0009-permission-policy-engine.md) | Work package 04 merged in GitHub PR #5 | Trusted policy authority, narrow bound sessions, explicit resource/field grants, revocable decisions and filtered responses; no providers or approval issuance. |
| [0010 Native application foundation](0010-native-application-foundation.md) | Work package 05 merged in GitHub PR #6 | Explicit synthetic policy composition, observable preview state, native navigation/menu/Settings and close-versus-quit behavior. |
| [0011 Calendar authorization/discovery](0011-calendar-authorization-discovery.md) | Work package 06 merged in GitHub PR #7; live TCC gate open | Explicit opt-in, isolated EventKit actor, local inventory/selection, revocation and async-result invalidation; no event reads or writes. |
| [0012 Calendar reads and availability](0012-calendar-reads-availability.md) | Work package 07 merged in GitHub PR #8; live provider gate open | Bounded selected reads, minimal fields, current real policy, recurrence/time normalization and conservative local coverage. |
| [0013 Google OAuth and Keychain](0013-google-oauth-keychain.md) | Work package 08 merged in GitHub PR #9; live activation blocked | PKCE/loopback, private credentials, refresh/cancellation/disconnect, separate revocation and explicit setup gates. |
| [0014 Google destination client](0014-google-destination-client.md) | Work package 09 merged in GitHub PR #10; live/privacy gates blocked | Internal authenticated transport, owned destination/event handles, conditional operations, bounded retries and unknown outcomes. |
| [0015 SQLite persistence](0015-sqlite-persistence.md) | Work package 10 merged in GitHub PR #11; no application activation | Versioned migrations, bound metadata, durable operation states/checkpoints, private local files and conservative restore. |
| [0016 Pure reconciliation planning](0016-pure-reconciliation-planner.md) | Work package 11 merged in GitHub PR #12; no live integration | Deterministic comparison, privacy projection, conflicts and guarded deletion proposals. |
| [0017 Synchronization executor](0017-synchronization-executor.md) | Work package 12 merged in GitHub PR #13; default-deny activation | Durable ordered execution, verified results and read-only unknown-outcome recovery. |
| [0018 Recurrence and time](0018-recurrence-time-correctness.md) | Work package 13 merged in GitHub PR #14; live gates open | Bounded materialization, anchor ambiguity, civil horizons, lossless timestamps and content-v2 compatibility. |
| [0019 Deletion safety and recovery](0019-deletion-safety-recovery.md) | Work package 14 merged in GitHub PR #15; live activation denied | Exact destructive batch approval, verified metadata reconstruction, legacy recovery and cooperative writer transfer. |
| [0020 Background synchronization](0020-background-synchronization.md) | Work package 15 merged in GitHub PR #16; sync inactive | Serialized monotonic scheduling, invalidation/drain, bounded safe retries, native lifecycle hints and opt-in login. |
| [0021 Google sync onboarding](0021-google-sync-onboarding.md) | Work package 16 merged in GitHub PR #17; live acceptance open | Bound local reviews, privacy choices, serialized orchestration and paused preference restoration. |
| [0022 MCP server foundation](0022-mcp-server-foundation.md) | Work package 17 merged in GitHub PR #18; synthetic only | Bounded stdio, dual-era metadata/lifecycle, typed mock tools and independent SDK checks. |
| [0023 MCP Calendar reads](0023-mcp-calendar-reads.md) | Work package 18 merged in GitHub PR #19; live identity/signed gates open | Policy-filtered synthetic discovery, availability, title search and refetched details with opaque handles. |
| [0024 MCP connection identity](0024-mcp-connection-identity.md) | Work package 19 merged in GitHub PR #20; synthetic peers only | Channel-bound local review, saved candidates, invalidation/cancellation and bounded private audit; signed/native gate remains open. |
| [0025 Action proposals and approval](0025-action-proposal-approval.md) | Work package 20 merged in GitHub PR #21; mock writers only | Exact local review, expiring single-use confirmation, serialized conditional dispatch and unknown-outcome blocking; native sample screen. |
| [0026 Journaled Calendar mutations](0026-calendar-mutation-journal.md) | Work package 21 merged in GitHub PR #22; production factory denies | Durable intent/receipt admission, restart containment and explicit EventKit conflict/recurrence limits. |
| [0027 Reminders reads](0027-reminders-reads.md) | Work package 22 implemented for review; live MCP gated | Independent authorization, native selected-list reads, async cancellation, field projection and paired MCP read tools. |

Read the records relevant to the active PR. No provider/authentication/persistence
architecture is considered decided merely because the product specification suggests
an approach. [Open decisions](../../../plans/MacHandleMasterImplementationPlan.md#unresolved-decisions-and-deferred-scope)
name the owner/gate for future ADRs.

New records should include date/status, context and evidence, the selected decision,
alternatives, tradeoffs, constraints, consequences, verification limits and links
to affected requirements/PRs. Record unresolved assumptions rather than inventing
support. Supersede explicitly; preserve earlier rationale in Git and linked records.
