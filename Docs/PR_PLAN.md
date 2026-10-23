# Incremental PR plan

Roadmap IDs are work packages, not GitHub issue numbers. This file tracks delivery;
the master specification remains canonical for product scope. A later package
becomes eligible only after its listed prerequisites are verified merged.

| ID | Title | Dependencies | Status | GitHub PR | Merge commit | Outstanding risk |
| --- | --- | --- | --- | --- | --- | --- |
| PR-01 | Repository Foundation and Security | Existing main initialization | Implemented; local checks passed; awaiting PR review | — | — | No provider or release functionality |
| PR-02 | Technical Feasibility and Architecture Decisions | PR-01 | Planned | — | — | Sandbox, scope and compatibility decisions unverified |
| PR-03 | Core Resource and Domain Models | PR-02 | Planned | — | — | Stable identities and typed semantics |
| PR-04 | Permission Policy Engine | PR-03 | Planned | — | — | Cross-connection isolation and revocation |
| PR-05 | Native Application Foundation | PR-04 | Planned | — | — | Mock UI must not imply live connections |
| PR-06 | Calendar Authorization and Discovery | PR-05 | Planned | — | — | OS permissions and missing accounts |
| PR-07 | Calendar Reading and Availability | PR-06 | Planned | — | — | Bounded reads and completeness |
| PR-08 | Google OAuth and Keychain | PR-07 | Planned | — | — | Migration and credential recovery |
| PR-09 | Google Destination Client | PR-08 | Planned | — | — | Public OAuth verification and token lifecycle |
| PR-10 | SQLite Persistence | PR-09 | Planned | — | — | Destination ownership and narrow scopes |
| PR-11 | Pure Reconciliation Planner | PR-10 | Planned | — | — | Deletion from incomplete snapshots |
| PR-12 | Synchronization Executor | PR-11 | Planned | — | — | Partial remote writes and retry identity |
| PR-13 | Recurrence, All-Day, and Timezone Correctness | PR-12 | Planned | — | — | Recurrence identity and timezone edges |
| PR-14 | Deletion Safety and Recovery | PR-13 | Planned | — | — | Cross-device ownership and mass deletions |
| PR-15 | Background Synchronization | PR-14 | Planned | — | — | Sleep/wake and overlapping work |
| PR-16 | Google Sync Onboarding and Preferences | PR-15 | Planned | — | — | Synthetic end-to-end proof required |
| PR-17 | MCP Server Foundation | PR-16 | Planned | — | — | No live data in initial transport |
| PR-18 | MCP Read Operations | PR-17 | Planned | — | — | Every read must enforce policy |
| PR-19 | MCP Connection Authentication and Revocation | PR-18 | Planned | — | — | Caller impersonation and revoked sessions |
| PR-20 | Safe Action Proposal and Approval Engine | PR-19 | Planned | — | — | Approval replay and exact-operation binding |
| PR-21 | Authorized Calendar Mutations | PR-20 | Planned | — | — | Synthetic-only mutations and version conflicts |
| PR-22 | Reminders Provider and Read Operations | PR-21 | Planned | — | — | Independent list permissions |
| PR-23 | Authorized Reminders Management | PR-22 | Planned | — | — | Recurrence and completion semantics |
| PR-24 | Contacts Discovery and Read Operations | PR-23 | Planned | — | — | Minimized fields and unified identities |
| PR-25 | Authorized Contacts Management | PR-24 | Planned | — | — | Contact deletion and stale state |
| PR-26 | Apple Notes Feasibility and Security Review | PR-25 | Planned | — | — | Mandatory supported-API decision gate |
| PR-27 | Optional Notes Integration | PR-26 | Conditional / planned | — | — | Conditional on PR-26 decision |
| PR-28 | Remote MCP Compatibility and Secure Connection | PR-25, PR-26 decision; PR-27 if implemented | Conditional / planned | — | — | Authentication and external compatibility |
| PR-29 | Diagnostics, UX Hardening, and Security Audit | PR-28 | Planned | — | — | Independent audit and redacted support |
| PR-30 | Public Release Engineering | PR-29; PR-28 may be explicitly deferred | Planned | — | — | Credentials, signing and notarization |
| PR-31 | ChatGPT Plugin Packaging and Distribution | PR-30 | Conditional / planned | — | — | External platform approval may block |

The initial conservative sequence keeps one PR per session. Reorder only with an
explicit documented dependency decision. PR-27 may be a deferral decision, and
PR-28/31 must not force unsupported remote/plugin functionality into a release.

Next: finish PR-01 review. PR-02 is eligible only after PR-01 merges. Initial
briefs: [PR-01](PRs/PR-01.md), [PR-02](PRs/PR-02.md), [PR-03](PRs/PR-03.md).
Create/refine subsequent briefs as the preceding implementation supplies evidence.
