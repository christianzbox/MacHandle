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

## Suggested next bounded choice

Prefer the **local broker/native pairing implementation and isolated read acceptance** track before
ChatGPT packaging. It connects the existing policy and provider modules to an actual client and
supports the user's Reminders priority without adding Google or remote infrastructure. First scope
the exact missing composition and signing prerequisites; do not treat an account alone as activation.
Native writes require their own exact-approval/provider evidence after reads work.

If account setup or live testing is still postponed, a separately authorized account-free bridge
design/fixture harness can reduce implementation uncertainty, but cannot close signed peer or actual
provider gates. The Notes prototype is another explicit choice once an isolated environment is ready;
its feasibility remains uncertain and must not block safe Reminders progress.

Use the [account checklist](../development/account-release-checklist.md) for Apple/Google preparation
and the [ChatGPT matrix](../development/chatgpt-distribution.md) for client/distribution prerequisites.
No extra database account is needed. Keep keys/tokens/private profiles out of Git and chat.

## Current authorized slice

The [six-slot private Reminders finish line](../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line) is recorded. Slot 1 merged in GitHub PR #34/#35. [Slot 2](prs/private-reminders-slot-2.md) selected reads is now the only authorized implementation, account-free and sample-tested. Real EventKit/TCC remains open until a separately authorized isolated test account is verified; personal iCloud stays untouched. Stop for review before slot 3.


The [native bridge sample pairing follow-up](prs/native-bridge.md) now implements an app-side broker,
native review and anonymous XPC fixture transport. It proves an in-process sample read path, not a
signed externally launched helper. Retained deployment gate after the slot 1 fixture proof: supported scoped discovery and mutual signed
peer verification with isolated fixtures, approved development identity and separate authorization.
Current OS/provider observations and real source access remain closed. No personal iCloud testing.

The [slot 1 completion](prs/private-reminders-slot-1.md) now verifies a sandboxed sample app, native approval and real MCP relay on the current Mac. Real isolated providers remain slot 2; actual desktop-client acceptance is slot 5 and stable private-build handoff slot 6. Minimum-OS runtime remains a compatibility gate before expanding machines/claims.
