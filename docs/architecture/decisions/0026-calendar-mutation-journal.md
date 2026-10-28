# ADR-0026: Journaled Calendar dispatch and an explicit EventKit activation gate

Date: 2026-10-28. Status: implemented for work package 21 review; live activation denied.
Requirements: [PR-21](../../product/master-spec.md#pr-21--authorized-calendar-mutations),
[§4](../../product/master-spec.md#4-security-and-permission-model),
[ADR-0025](0025-action-proposal-approval.md), [ADR-0024](0024-mcp-connection-identity.md).

## Decision and trust boundary

Add CalendarMutations, depending on CoreDomain, PermissionEngine, ActionApprovals and
SyncPersistence. Its package-internal JournaledCalendarProvider implements the trusted approval
provider; its backend protocol and EventKitMutationBackend are internal. Neither target is an
MCP/helper/application dependency. No public writer, EventKit object, writable saved grant,
permission request, real account, or new MCP tool is exposed. Google source access stays read-only.

AuthorizedCalendarAction now carries a trusted, nonserializable revalidation closure constructed
only by the approval engine. It rechecks the bound permits, policy/OS/channel generations,
cancellation, engine invalidation and review/confirmation deadlines. The adapter checks it after
durable preparation; the backend checks it again after its last suspension. This closes the
journal-await gap without treating persistence or a caller boolean as authority. It does not make
asynchronous policy and external database state one atomic transaction.

The production factory always denies, before constructing EventKit or opening a calendar. There
is no environment switch or caller assertion to bypass it. The native UI remains the package 20
synthetic preview, including its sample-only outcome messages. This is implemented adapter and
recovery infrastructure, not completed live Calendar acceptance or milestone C.

## Durable admission and restart behavior

CalendarMutationJournal uses a separate private directory and schema through the existing
hardened SQLite connection. FULL synchronous commits and fullfsync, exclusive writer locking,
owner-only files, no-follow checks and inode/sidecar validation are reused. Application ID,
schema version, exact table definitions, installation UUID and quick_check are verified. Existing
or missing stores cannot silently become new ones. No default path or production store is created.

Persist only a random operation UUID and fixed pending/applied/notApplied/unknown state. Event
arguments, names, source IDs, provider errors and approval handles are never persisted. The
installation identity is not authentication. One pending or unknown record blocks all subsequent
writes through that journal, including after engine/process restart. A committed pending intent
must precede provider acceptance. A valid matching receipt is persisted before reporting success.
Provider errors, mismatched receipts and receipt-write failure become unknown; cancellation after
acceptance still persists the actual receipt. Explicit nonacceptance may be recorded as notApplied.

An operation UUID can never be reused. There is no clear, delete, retry or auto-resolution API.
The journal retains at most 4096 records, then fails closed; future reviewed retention must preserve
replay tombstones. A crash between intent commit and dispatch deliberately requires recovery even
if no provider write happened. This sacrifices availability to avoid duplicate creates. A crash
between provider acceptance and receipt commit also remains pending. These states are recovery
candidates, not permission to reconstruct or replay an approved request.

Automatic EventKit reconciliation was rejected: an absent event is not proof of a successful
delete, local cache reads are not upstream completeness, and matching event content does not prove
which writer created it. The metadata-only journal intentionally cannot attribute a lost create
receipt. Engineering owns a reviewed recovery/retention design and native recovery presentation
before activation. The present safe recovery outcome is durable containment; no reset-by-restart
or exactly-once external-effects claim is made.

## EventKit adapter and conflict semantics

The backend owns one lazy EKEventStore and never requests permissions. It checks full EventKit
access, exact provider/store/source/calendar reference, entity support and current writability.
Existing items require exact local item identity, successful refresh, matching observation token,
reviewed fields and labels, and active supported state. Missing/foreign/changed targets fail closed.
Only requested title/location/notes fields enter snapshots; unchanged event properties are not set.
Create/update/delete use immediate commits and `.thisEvent`, never batched or future-series writes.
Raw provider exceptions are reduced to unknown, without logging content or claiming rollback.

Initial supported candidate scope is standalone events. Recurring/detached items, occurrence dates,
unknown anchors/versions, invitations/organizers, unsupported availability, floating timed events,
subsecond write times and all-day writes in a different system zone are rejected explicitly.
All-day mapping preserves civil dates and exclusive ends across DST. No first-occurrence lookup is
silently accepted as a requested recurrence instance. Engineering owns recurrence and broader time/
meeting support; revisit with isolated provider fixtures before enabling those capabilities.

An observation token derives from EventKit's lastModifiedDate and is compared alongside the
reviewed snapshot. It is not a provider CAS revision, may have limited resolution and does not
prove unseen fields stayed unchanged. Existing read services continue returning unknown mutation
preconditions; no unapproved live mutation-candidate read route is introduced. A future live read/
proposal path must obtain a scoped current observation under its own policy permit.

The final refresh/compare/patch/save runs without an actor suspension, but external apps and cloud
sync can change the store concurrently. Apple documents that save updates untouched fields and can
recreate an item deleted from the database. Consequently local equality cannot promise atomic
conflict rejection. We rejected claiming the mock actor's atomicity as EventKit evidence. The
activation gate retains this unresolved product conflict requirement; engineering must establish
an acceptable explicit conflict policy or keep affected operations disabled. A save receipt proves
local EventKit acceptance only, not remote synchronization or absence of an external race.

## Evidence and activation ownership

Twelve adapter/scope tests plus four journal tests exercise all three approved mutations, durable
ordering, receipt identity, cancellation before/after acceptance, revocation after intent, serialized
engines, unknown/pending reopen, replay, identity/lock/schema/file protections, transactional rollback,
foreign/unsafe targets, explicit recurrence rejection and DST/precision limits. EventKit API code
compiles with the pinned SDK; tests use in-memory providers and temporary synthetic SQLite stores,
never personal calendars or actual EKEvent objects. Three new negative compiler probes keep the
journal/writer/backend inaccessible to external callers. Existing approval/policy tests retain
field denials, stale conflicts, Google-source rejection and exact preview behavior.

Engineering/maintainer own approved signing identity, mutually verified broker/current OS wiring,
explicit writable grants, live candidate reads and native review/outcome/recovery UI. They also own
isolated physical-Mac/sandbox/minimum-OS recurrence, time and concurrent-edit/delete experiments.
Trigger: approved identity plus explicit synthetic-calendar setup, before changing the live factory.
No setup has been supplied; these are open acceptance gates, not silently completed requirements.

## Official references reviewed 2026-10-28

- [Apple: save event](https://developer.apple.com/documentation/eventkit/ekeventstore/save(_:span:commit:)) — immediate commits and deleted-item recreation caveat.
- [Apple: refresh](https://developer.apple.com/documentation/eventkit/ekevent/refresh()) — refresh validates an existing event, not a database transaction lock. Also checked the pinned SDK header.
- [Apple: event lookup](https://developer.apple.com/documentation/eventkit/ekeventstore/event(withidentifier:)) — first occurrence does not identify an arbitrary recurrence instance.
- [Apple: creating events and reminders](https://developer.apple.com/documentation/eventkit/creating-events-and-reminders) — explicit user instruction and save/remove spans.
- [MCP tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) — local human review remains distinct from tool annotations and model arguments. No mutation tools are advertised here.
