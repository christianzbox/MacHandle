# ADR-0016 — Pure reconciliation planning

Date: 2026-10-27. Status: work package 11 implemented for review, no live integration.
Requirements: specification PR-11, §§4, 7.5–7.10 and 20. Prerequisite GitHub PR #11
merged at `4a5ad09a22be45b681c46675d756500603a58d8c` on 2026-10-27 20:05:30 UTC.

## Decision, alternatives and boundaries

Add SyncPlanning, a pure synchronous target depending only on CoreDomain, Foundation
and SDK CryptoKit. Reuse CalendarSnapshot, occurrence identity, time and observation
contracts. Keep planner-specific observations/proposals outside CoreDomain until another
consumer needs them. The app links the module for universal compilation but does not
invoke it. No storage, HTTP, EventKit, Keychain, clock, randomness or side effects enter
planning. No provider capabilities or Apple mutation proposals are produced.

A combined planner/executor would obscure comparison tests and allow dispatch before
current authority checks. Putting SQL/Google objects in the planner would couple it to
transport and recovery implementation. Instead explicit immutable comparison inputs
represent one source calendar and one destination, with a current policy revision.
Composition may call the planner per resource; multi-calendar orchestration is package 12.
An enabled policy and verified evidence are caller-supplied data for comparison, **not
proof or authorization**. The future trusted adapter must establish these observations;
no public enum or plan can construct the existing internal Google capabilities.

## Preconditions and comparison

The planner rejects the whole input for disabled policy, mismatched selection/scope or
window, incomplete source/destination enumeration, unknown/stale freshness, unverified
identity/ownership, missing/corrupt/unverified mappings, unresolved operations, duplicate
identities, unknown recurrence anchors or untracked destination records. Defaults deny.
Each collection is bounded at 10,000 entries and the existing 400-day source bound applies.
Source all-day coverage is resolved explicitly; machine-local timezone is never used.

Both snapshots must carry verifiedThrough at least their observedAt. This compares
explicit evidence, not the wall clock or an invented expiry. Current EventKit local-cache
reads cannot satisfy this gate automatically. Trusted freshness/absence and provider
snapshot consistency remain integration gates; callers must not relabel a cache as verified.
The executor must reacquire observations and revalidate authorization at dispatch.

For validated inputs:

- An unmapped active source proposes create; a cancelled unmapped source is no-change.
- A mapped event requires verified ownership, the stored version and the stored content
  fingerprint to still match remote observations. Any divergence is a conflict, even if
  the remote content now happens to match desired content. No silent overwrite or adoption.
- Equal projected content yields no-change; changed content proposes a conditional update.
- A missing mapped destination requires manual intervention, never a replacement create.
- Confirmed cancellation can propose deletion. Absence from a bounded enumeration cannot:
  a moved occurrence may be outside the horizon. Separate trusted confirmedAbsent evidence
  is required, the last source interval must be fully within coverage, and the destination
  must still match the mapping. A shifted horizon never cleans up old mappings by itself.
- Tombstones cannot silently resurrect; unknown source status/occupancy and unavailable
  selected fields require manual intervention. Conflicts remain visible during privacy
  reduction, so the UI must not claim sensitive remote fields were removed.

Every deletion proposal requires local confirmation, including a single deletion. This
conservative rule also covers mass deletions without a guessed numerical threshold.
There is no approval receipt or execution path here. Package 12/20 must bind exact
confirmed proposals and recheck their current preconditions; package 14 owns recovery.
Other safe item proposals may coexist with item conflicts; no plan implies run completion.

## Projection and deterministic identity

Availability is the default: Busy, empty location/notes, original timed or exclusive-end
civil-day bounds, free versus occupied semantics. Tentative becomes occupied; unknown
occupancy requires intervention. Detailed fields require explicit per-field selection
and fetched values; authorized nil is different from missing/unauthorized. Deselected
fields are explicitly empty in replacement content, clearing prior detail on update.
There is no guest, invitation, attachment or conference field. Payload strings are bounded
at 8192 UTF-8 bytes; hidden source fields are neither copied nor fingerprinted.

Fingerprints use SDK SHA-256 over versioned, UTF-8 byte-length-prefixed components.
Time encoding uses finite instant bit patterns with canonical zero, or civil date
components plus explicit timezone; it does not use locale or Swift's randomized Hasher.
Occurrence keys include provider/store/account/calendar/item and the original recurrence
anchor, never mutable current start time. These are local identity-domain keys, not
universal cross-Mac or resync identifiers. Digests are not encryption or anonymization.

Output order is sorted by occurrence digest. Proposal IDs additionally bind destination,
policy revision/field selection, action and relevant expected version/content. No UUID
or current time is generated. Proposal IDs are comparison identifiers only; the executor
must durably prepare actual operation and remote IDs before dispatch. Fingerprint version
changes require explicit migration/rebaseline decisions, never silent adoption.

The planner models explicit timezones and time precision; a future Google adapter must
normalize source/remote representations consistently and reject lossy conversions.
Provider recurrence identity, DST exceptions, moves across calendars and timezone changes
remain package 13 acceptance work, not proven by these synthetic comparisons.

## Evidence and deferred integration

Eighteen public-API synthetic tests cover create/update/no-change convergence, permutation
determinism, a SHA-256 vector independently derived in Python, privacy reduction and
field minimization, missing/partial/stale observations, identity/mapping failures, unknown
outcomes, conflicts, explicit deletion evidence, horizon boundaries, tombstones, all-day/
free/tentative projection and size bounds. A new compiler rejection proves a planner
proposal cannot be passed as an Apple write proposal; dependency/import guards isolate
infrastructure. Exact staged/final-head gates and hosted results belong in the PR and
[progress](../../implementation/progress.md).

Deferred owners and triggers: after explicit authorization, package 12 owns trusted
source/destination/storage adapters, real account/policy/writer rechecks, preview/approval
handoff and ordered execution; package 13 owns recurrence/time/provider identity acceptance;
package 14 owns lost-state/ambiguous outcome recovery, absence verification and writer
transfer. No database, source provider or Google client calls this module yet. Signed,
minimum-OS, live OAuth/privacy, home-Mac and end-to-end gates remain open. Package 12's
brief is preparation only. No real user content or account was accessed.
