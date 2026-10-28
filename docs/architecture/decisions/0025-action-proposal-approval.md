# ADR-0025: Exact local action reviews and single-use dispatch

Date: 2026-10-28. Status: implemented for work package 20 review, mock Calendar writers only.
Requirements: [PR-20](../../product/master-spec.md#pr-20--safe-action-proposal-and-approval-engine),
[§4.7](../../product/master-spec.md#47-action-approvals),
[§8.3](../../product/master-spec.md#83-mcp-mutation-safety),
[ADR-0009](0009-permission-policy-engine.md) and [ADR-0024](0024-mcp-connection-identity.md).

## Decision and boundaries

Add ActionApprovals, depending only on CoreDomain and PermissionEngine. Its package-internal
CalendarApprovalEngine accepts one already-bound PolicySession, a trusted provider contract,
a monotonic clock and a current channel/OS authorization callback that defaults to false.
It cannot select a different identity; the session exposes its bound connection to trusted
package composition only. This is not an authentication API. No live Calendar writer,
EventKit mutation, MCP mutation tool or extension to saved MCP read grants is introduced.
Google source writes remain denied by policy. The app exposes only a fixed synthetic preview.

The first supported proposal family is typed Calendar create/update/delete. Each request
gets an engine-generated operation ID; the engine retains the exact immutable mutation,
provider target/state, mutation and review-read permits, and local review nonce. A policy
receipt remains distinct from local approval. A new point-read policy request authorizes only
fields needed to review an already-permitted mutation, with readDetails and explicit field
grants. Unknown preconditions, unselected resources, unavailable fields and Google sources
are denied. Existing read filters cannot use this new receipt as a broad read permission.

The provider supplies exact account/calendar reference and writable target evidence, plus
current item identity/revision and requested fields. The engine verifies scope and projects
over-returned fields before retaining state. Update and delete need an active matching item;
incomplete, missing or unknown state is not proof that a mutation is safe. Create reviews
verify the chosen writable calendar but never infer an existing event from an empty read.

## Local review and execution

A review lasts at most 120 monotonic seconds from preparation. Its display includes account,
calendar, event/occurrence scope and exact before/after values. Text is quoted as literal data;
clearing a field is visibly different from setting the text “Not set.” Control/format characters
that could spoof the review, oversized fields and no-op updates are rejected. Notes may contain
escaped newlines/tabs. Times preserve UTC instants and source zone; all-day dates retain their
exclusive end. Unusual sub-millisecond instants also show exact epoch seconds so the preview
does not silently round approved arguments. No resource text is interpreted as instructions.

Only trusted local administration can confirm. Delete requires an additional explicit
acknowledgement. Confirmation reserves the review before suspension, rechecks policy/channel/OS
and returns a nonconstructible, non-Codable handle. It expires after 30 seconds or the original
review deadline, whichever is sooner. Reject/invalidate closes pending reviews. Foreign or old
review/confirmation handles cannot choose another engine, connection, target or payload.

Commit accepts only that handle, never replacement arguments. Consumption and admission to
one serialized execution slot happen together before suspension. A competing confirmation is
consumed and rejected instead of queued; a repeated request cannot replay it. Recheck current
policy, channel/OS and expiry, refetch exact provider state, compare it to the approved snapshot,
then revalidate again immediately before dispatch. The provider must conditionally compare
and mutate at its own supported acceptance boundary. The mock actor does this without an await;
work package 21 must prove the real EventKit conflict behavior rather than claim atomic support.

Cancellation/invalidation before dispatch prevents the write and consumes approval. After
dispatch an accepted action may finish; report a valid receipt as applied even if cancellation
or revocation arrived afterward. A thrown/lost/mismatched receipt becomes unknown, clears
pending reviews and blocks further writes on that engine. Never automatically retry a create
or claim rollback. Only fixed metadata is returned; provider content/errors are not logged.

Limits: four preparations, sixteen pending reviews/confirmations, one execution and 128 audit
records per engine. Suspended preparation retains its slot. Audit contains sequence, operation
ID, bound connection ID and phase only, without target IDs, arguments, labels or content.
Expiry is checked on actions and pruned on preparation/confirmation, not by an idle timer.

## Native sample review and alternatives

MacHandleApplication owns a public synthetic-only presentation model. Connections offers
sample create/update/delete reviews, inert before/after rows with explicit accessibility labels,
cancel, and separate deletion acknowledgement. Every sample starts a fresh isolated mock;
it cannot enable the selected real or sample connection's grants. No account, permission,
credential, real resource or external client is touched. Old UI IDs and dismissed/late reviews
cannot confirm the replacement. The live pairing screen from package 19 is still absent.

We chose typed retained proposals and opaque local handles over client-supplied approval booleans,
signed JSON tokens or caller-provided operation IDs. This avoids argument replacement and token
parsing/canonicalization at this stage, but cannot cross a process or survive restart. We chose
one execution slot over queued confirmations to avoid executing approvals after an unpredictable
wait. Calendar-specific validation precedes generalization: Reminders/Contacts need their own
field, target and deletion rules in their owning packages. No generic unrestricted writer exists.

In-memory proposals, receipts and audit suffice for the explicit mock preview. They do **not**
provide crash recovery or durable exactly-once effects. Before real dispatch, engineering owns
a durable pre-dispatch journal, unknown-outcome recovery and restart behavior in package 21;
SQLite is the preferred durable transaction store. Reusable bearer approvals and unattended
writes remain unavailable. No existing Google synchronization approval is reused for source writes.

## Evidence and retained gates

Twenty engine tests plus two presentation-model tests cover exact create/update/delete effects,
foreign/stale/replayed handles, expiry, deletion acknowledgement, policy/OS revocation during
suspended work, cancellation before/after dispatch, serialized concurrency, stale/provider-race
conflicts, read-only MCP and Google rejection, projection, bounds and uncertain receipts.
The [developer checks](../../development/action-approvals.md) record native preview scope.
Full staged/final-head evidence belongs in [progress](../../implementation/progress.md) and the PR.

Engineering/maintainer retain package 19's approved signing identity, mutually verified broker,
current OS/channel/transport wiring, native live review integration and actual client/minimum-OS
acceptance before personal-data use. Package 21 additionally owns live write-grant configuration,
provider target writability/version/recurrence checks, journal/recovery and synthetic-resource
end-to-end acceptance. Trigger: approved identity and explicit isolated test setup, before any
live source write. This package establishes mock approval behavior, not milestone C completion.

## Subsequent package 21 decision

Package 20 merged in GitHub PR #21. [ADR-0026](0026-calendar-mutation-journal.md) adds a trusted
revalidation closure for the journal-await boundary and a separate gated EventKit adapter/journal.
It explicitly does not inherit the mock's atomic compare-and-mutate guarantee. Durable restart
containment is implemented; signed/native wiring, provider conflict policy and live recovery
acceptance remain open before activating any real writer. This record's original evidence is unchanged.
