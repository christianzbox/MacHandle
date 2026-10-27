# ADR-0017 — Durable synchronization execution

Date: 2026-10-27. Status: work package 12 implemented for review, synthetic integration
only; live activation remains blocked. Requirements: specification PR-12 and §§4, 7, 20.
GitHub PR #12 merged at `567b5a1a644c4b1ccba10eb21687c8d84d5c82cf` on 2026-10-27
20:20:09 UTC. No accounts, source content or live service were accessed.

## Decision and alternatives

Add an internal SynchronizationExecutor actor in SyncExecution. It depends explicitly
on CoreDomain, SyncPlanning, SyncPersistence and GoogleAuthorization, never EventKit,
AppleCalendarProvider or UI. The app links the target for compilation but cannot construct
its internal executor and never invokes it. Planner/domain/storage dependencies stay
unchanged. GoogleAuthorization still has no dependencies on the planner or persistence.

A package-only GoogleDurableDestination bridge is issued inside GoogleAuthorization from
an already session-owned destination handle. There is no public/package constructor or
live activation factory. Narrow wire value types and sanitized failures become package
visible, while bearer access, authentication leases and the destination client remain
internal. Exposing raw provider capabilities publicly was rejected; moving execution into
authentication would couple independent modules. Swift package access permits trusted
module integration without an external caller bypass; it is not a security sandbox.

ExecutionAuthorizing is an internal injected contract for current source-read/destination
observations and per-request authorization. Its default InactiveExecutionAuthority denies
both methods. No live implementation exists. The trusted implementation must verify actual
account/client/store binding, current source selection/OS access/field policy, destination
privacy/ownership, writer lease, preview generation and exact deletion confirmation.
Comparison enums and caller assertions are not substitutes. Synthetic tests implement
this contract solely with fixtures. A real adapter must not relabel local-cache reads as
verified freshness. Keeping activation denied is required by the existing unresolved
privacy/signing/freshness gates, not evidence that these gates have been solved.

## Ordered execution and persistence

run obtains a fresh comparison input and requires its recomputed plan to equal the reviewed
preview exactly. Any global issue or item conflict/manual intervention stops before writes.
It validates the bound SQLite identity, calendar source digest, destination ID/marker,
completed calendar-creation history, all supplied mapping IDs/fingerprints/versions and
absence of prepared/unknown operations. One invocation processes one resource in the
planner's stable order; composition can sequence resources, but no multi-resource atomic
transaction or background orchestration is claimed. An actor busy guard rejects overlap.

Each change is checked against the current trusted authority before preparation. Create
persists a stable occurrence key, remote event ID and operation; update/delete retain
mapping identity and version. Wire conversion happens before preparation and rejects
subsecond timed values that the current Google formatter would truncate. All-day dates
retain exclusive ends. Comparisons use semantic instants/civil dates; planner timezone
metadata remains local. Provider recurrence/timezone correctness is package 13's gate.

beginAttempt must commit unknown before dispatch. The bridge uses the persisted event ID,
creation-operation marker and current mutation ID; it never generates a replacement event
ID. Updates/deletes first GET and verify ownership, prior content and ETag, then use If-Match.
Every actual HTTP attempt, including quota retries, rechecks authority and cancellation;
Google transport continues fencing the authentication lease. A conflicting version has
no unconditional fallback. Retry policy remains bounded known-rejection retries only;
transport failures and mutation 5xx are unknown, never blind retries.

A successful mutation response alone is insufficient. A separate GET verifies ID, owner,
creation/mutation marker, desired content, private visibility and disabled default reminders;
delete requires verified absence in the still-owned destination. Only then, after another
authority check, does SQLite atomically record the result and completion. A failed result
commit retains unknown state. Earlier completed items survive later failure. Only a fully
processed plan with a final authority check can advance the expected checkpoint revision.
No conflict, cancellation, uncertain write or failed local commit is reported as success.

## Recovery boundary

recover verifies one exact persisted unknown operation against its original proposal and
current trusted authorization. It performs reads only; it cannot resend a mutation, invent
an ID or advance a checkpoint. Successful recovery is reported as recovered, not completed;
new observations and a fresh plan are required for run completion. Missing remote inserts,
wrong markers/content, unresolved prepared intent or changed desired state remain blocked.
Deletion absence is accepted only for the bound persisted operation in the owned calendar.

Tests reopen the SQLite store and construct a new executor while retaining the already
owned Google session. They do not prove whole-process/provider-session restoration.
Reconstructing a destination capability from disk or a remote title/marker, lost calendar
creation responses, missing mappings and device transfer remain package 14. A durable
calendar ownership marker can now be supplied to the existing internal creation method;
the synthetic bootstrap commits its intent first. Onboarding/production bootstrap and
private-calendar acceptance remain package 16; the executor requires an existing verified
resource and never creates or replaces calendars itself.

The local file lock and executor busy guard are not a cross-Mac writer lease. The trusted
authorizer must establish that lease before live use. No network authorization can create
a distributed transaction with the provider; conditional versions, immediate pre-send
checks and retained unknown outcomes define the practical race boundary.

## Evidence and remaining owners

Fifteen new tests use real disposable SQLite files, the real planner/executor/Google client
and an injected synthetic HTTP transport. They exercise ordered durable creates, convergence,
privacy clearing, conditional deletes/confirmation, lost insert/update/delete responses,
store reopen, failed result persistence, missing recovery targets, version races, quota
revocation, cancellation/concurrency, partial success and lossy-time rejection. No real
network, account, Keychain or Apple provider is used. Existing storage failure-injection and
Google transport suites remain in the full gate. Two new compiler probes reject external
executor/bridge access; import/dependency guards prohibit Apple providers in execution.

The tests verify the executor's calls to the trusted authorization contract, not a live
policy/approval service. Exact final-head local/hosted evidence belongs in the review PR
and [progress](../../implementation/progress.md). No tokens/content/logs/databases enter Git.

Deferred owners/triggers: package 13 for recurrence/time/identity acceptance; package 14
for whole-process destination reconstruction, prepared-intent resolution, source absence,
lost mappings and cross-Mac writer transfer; package 16 for trusted live composition,
private-calendar acceptance, preview/confirmation UI and bootstrap. Revisit after those
packages are authorized and maintainer setup/signed isolated-account testing is authorized.
Package 20 owns general MCP approvals; this package does not enable MCP. Signed Keychain,
OAuth/privacy, minimum-OS, home-Mac and end-to-end gates remain open. Package 13's brief
is preparation only; no next-package implementation or merge is authorized here.
