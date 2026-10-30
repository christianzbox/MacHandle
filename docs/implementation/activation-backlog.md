# Activation and acceptance after the numbered roadmap

Work packages 01–31 are merged; GitHub PR #32's verified squash is
`34ad4c3e4e0165123cda48b9b3808adab8e7fd36`. The original numbered sequence has ended.
It does **not** mean a functioning end-to-end product, live Notes/ChatGPT, or a release is complete.
No release milestone has been accepted. Actual evidence stays in [progress](progress.md).

This is a navigation index under the [master plan](../../plans/MacHandleMasterImplementationPlan.md),
not a second requirements or acceptance ledger. Linked gates own their detailed closure criteria.
There is no fixed remaining PR count: each chosen gate may need implementation and acceptance PRs.
One bounded follow-up at a time; do not automatically activate services or begin testing personal iCloud.

| Remaining work | Owner and prerequisite / revisit trigger | Authoritative acceptance |
| --- | --- | --- |
| Signed identity, broker, native pairing and approval composition | Engineering; maintainer selects development identity and authorizes isolated setup. Start selected reads before writes | [ADR-0007](../architecture/decisions/0007-lifecycle-identity-and-distribution.md), [ADR-0024](../architecture/decisions/0024-mcp-connection-identity.md), audit G1 and release P1/P3 |
| Calendar/Reminders/Contacts provider and mutation acceptance | Engineering + maintainer; separate test user/accounts with synthetic fixtures, signed candidate and explicit provider-testing authorization | [Calendar writes](../architecture/decisions/0026-calendar-mutation-journal.md), [Reminders](../architecture/decisions/0028-reminders-management.md), [Contacts](../architecture/decisions/0030-contacts-management.md); retain recurring/alarm/list-move and contact mutation limits |
| Google activation and independent mirroring | Engineering; approved Desktop OAuth test client, signed Keychain identity and isolated destination. Not a prerequisite for MCP | [Package 16 open activation follow-up](prs/pr-16.md#open-activation-follow-up--not-a-completed-milestone), including private destination, recovery and two-Mac ownership |
| Notes supported-API prototype and subset decision | Engineering; maintainer authorizes isolated fixture/signing setup. No personal Notes access | [Notes G1–G6](../development/notes-feasibility.md#isolated-runtime-gate); all runtime capabilities still deferred |
| ChatGPT private desktop compatibility | Engineering; verified signed local bridge and confirmed intended account/client availability | [Package 31 setup and protocol](../development/chatgpt-distribution.md); actual read, write, revocation and recurring tests are separate |
| Optional authenticated remote access | Engineering + maintainer; selected identity/infrastructure route and approved isolated setup | [Remote R1–R6](../development/remote-mcp.md#activation-matrix); not required for local use |
| Audit, accessibility, privacy/export denial and sustained load | Engineering; integrated signed supported-service candidate | [Audit G1–G4](../development/diagnostics-security-audit.md#findings-and-disposition); source/unit checks do not close live findings |
| Home Mac, minimum/current OS and architecture compatibility | Engineering + maintainer; second device and signed candidate available | [Setup](../development/setup.md), release P4; one active Git writer and separate product ownership-transfer testing |
| Signed/notarized distribution and public plugin review | Maintainer + engineering; chosen advertised subset, account eligibility, all required service gates and explicit publication authorization | [Release P1–P5](../development/release-engineering.md#owned-release-gates), [ChatGPT deferral](../development/chatgpt-distribution.md#owned-deferral-and-revisit-trigger) |

## Current handoff and next decision

Slots 1–5 are merged through GitHub PR #39. [Slot 6](prs/private-reminders-slot-6.md) is the final
currently authorized sample installation/testing handoff, with its [first-session checklist](../development/private-testing-handoff.md).
The signed native bridge, local desktop sample workflow and sample recovery have scoped evidence in
[progress](progress.md); their completion does not close live provider or full-product gates above.

After slot 6 review, the maintainer can exercise that bounded sample workflow. Before more building,
scope and estimate the real-Reminders phase: isolated test environment/permissions, provider reads,
accepted external-writer conflict contract, guarded writes and recovery. Keep personal iCloud untouched
unless separately authorized. No unbounded sequence of follow-up PRs or account purchases is assumed.
Notes remains a separate feasibility decision and must not silently expand this Reminders finish line.

Use the [account checklist](../development/account-release-checklist.md) only when a chosen capability
needs it. No paid Apple enrollment, employer team, Google OAuth project, API key or database account is
needed for the current sample handoff. Minimum-OS, other-Mac and public distribution remain separate.
