# ADR-0008: Typed domain values and explicit uncertainty

Date: 2026-10-26 (America/Detroit). Status: implemented for PR-03 review, not merged.
Requirements: specification §§4, 6, 7.5–7.10, 9–10, 20 and PR-03.
Prerequisite: PR-02 merged in GitHub #3 at
`c96f4f0cbb54e2397d5c987a80cc2c0cd9ab0630`; rechecked before branching.

## Context and decision

Add one `CoreDomain` library target to the existing local Swift package. It has no
target/package dependencies and imports only Foundation for dates, timezone
validation and identifier validation. Public immutable values conform to Sendable
and, where equality is meaningful, Hashable. Public initializers allow use outside
the module without `@testable`. The app still links only the foundation metadata;
domain composition belongs to PR-05. No provider, transport, storage or policy engine
is introduced, and Swift 6/the pinned toolchain remain unchanged.

| Boundary | Selected representation and consequence |
| --- | --- |
| Identity | `DomainID<Kind>` preserves opaque, case-sensitive spelling and rejects empty/whitespace-only IDs. Distinct tags prevent connection/event/resource confusion. `AccountReference` includes provider, local store and account; resource references add a typed local ID. Equality describes this observed namespace, not cross-Mac or cross-resync identity. |
| Resolution | `ReferenceResolution` distinguishes resolved, missing, ambiguous and unavailable. Destination reference and ownership evidence are separate; names and OAuth scope cannot establish either. No mapping/recovery algorithm yet. |
| Authorization | `Connection` defaults disabled, with only an optional opaque credential handle. Connection state and `OSAuthorization` are separate from all future policies/approvals. Constructible values, including enabled/full-access/verified markers, never prove authority. |
| Time | Finite `Instant`, nonempty half-open instant intervals, validated Gregorian civil dates (years 1–9999), exclusive-end civil date intervals, explicit timezone identifiers and wall-clock time components. `EventTime` distinguishes timed/all-day. No current timezone or clock is read implicitly. |
| Occurrences | `OccurrenceReference` stores the original anchor independently from current event time and optional provider series ID. Nonrecurring and unknown anchors differ. A moved occurrence with unchanged provider reference/anchor retains identity; full-resync/move recovery still needs PR-07/13 evidence. |
| Reads | `CalendarReadRequest` requires a nonempty explicit calendar selection and bounded window. Snapshots reject other-calendar records and timed events wholly outside the window; overlapping events are retained. All-day window conversion remains a provider responsibility. |
| Completeness | `ObservationState` records observation instant, complete/partial/unknown enumeration and separate freshness (unknown by default). Partial reasons include further pages, provider limits and interruptions. A successful local enumeration never asserts upstream freshness. Failure results are distinct from observed empty snapshots. |
| Availability | `AvailabilityBlock` carries only interval and occupancy; it cannot carry event titles, notes, locations or item IDs. Blocks must fit the requested window. Partial/unknown coverage is retained, never interpreted as free time. Calendar selection metadata is internal; external response shaping remains PR-07/18. |
| Fields | `FieldValue` distinguishes unfetched, unauthorized and fetched values, including nil or empty arrays. Calendar detail and all Contact fields default unfetched. Field-level policy/filtering is still PR-04. |
| Reminders | Due values preserve date-only versus wall-clock time and explicit/floating zone. Completion is separate, including completed with unknown timestamp. Due never creates an alarm. |
| Contacts | Explicit name, email, phone, postal, organization and notes fields. Unified references span a provider/store and cannot be confused with underlying container/account records. Linked records remain an optional fetched field; mutation targets require an underlying record reference. |
| Mutations | Resource-specific operation enums; immutable typed create/update/delete payloads, distinct reminder completion/due operations. Patches distinguish unchanged from set, including clearing optionals/arrays; empty patches are rejected. Contact changed-field sets are derived from the payload. No unrestricted dictionary. |
| Proposals/results | `ProposedChange` binds operation ID, requesting connection and exact payload, including target and observed opaque revision or explicitly unknown precondition. No approved flag, token issuer, signature or Codable conformance. Mutation results distinguish success, conflict, failure and unknown outcome; unknown can mean the write completed. |
| Capabilities | `CalendarReading` and `CalendarWriting` are separate async Sendable interfaces; the read protocol neither inherits nor returns a writer. A compile-fail check proves a read-typed consumer cannot call `apply`. These are internal trusted adapter boundaries, not a security sandbox or external API. |

## Alternatives and tradeoffs

- Raw strings and a universal resource/payload dictionary would be shorter but hide
  namespace, field, time and target mistakes. Tagged IDs remove duplicate validation
  while concrete resource models retain their differences. The generic proposal,
  field and result wrappers share structure without erasing typed payloads.
- One protocol with reads and writes would simplify adapters but give synchronization
  a write dependency. Separate protocols make the intended injection explicit. A
  malicious in-process caller could still hold/cast a concrete dual-capability
  adapter; trusted composition and runtime policy enforcement remain mandatory.
- `Date` for every date, or 24-hour all-day durations, would lose floating/date-only
  semantics. Gregorian civil values avoid that implicit conversion. Providers must
  explicitly normalize supported calendar systems and preserve uncertainty; no
  recurrence expansion, DST ambiguity resolution or matching algorithm is selected.
- Nil-only fields and empty arrays for failures would erase privacy and completeness
  distinctions. Explicit enums cost more switch cases but force later consumers to
  handle unknown states. There is deliberately no `safeToDelete` convenience flag.
- Automatic Codable synthesis could bypass validated construction and prematurely
  define persistence/transport formats. Defer codecs to their owning boundary; they
  must validate input and cannot confer identity or approval. Hashable is in-process
  equality, not a durable fingerprint or cryptographic approval binding.
- A giant speculative model of every provider property would overfit untested APIs.
  This package supports the next policy work and minimal resource representations.
  Calendar attendees/invitations, series edits, reminder recurrence/alarms/list moves,
  additional contact/name components and provider-specific metadata remain planned
  in PR-07/13/21, PR-22/23 and PR-24/25. Owners revisit when implementing the provider;
  adapters must preserve unmodeled fields rather than treating this subset as a full
  replacement record. This is scope sequencing, not a dropped product requirement.

## Evidence and remaining gates

The public-API synthetic tests and compiler boundary checks are listed in the
[PR-03 acceptance map](../../implementation/prs/pr-03.md#implementation-and-acceptance-map).
The standard validator now checks the dependency/import rule, a positive compiler
control, and three expected rejections: read interface used as writer, wrong ID
kind, unified contact passed as an underlying deletion target. Temporary compiler
fixtures are removed on exit. No weaker CI flags, credentials or entitlements.

These tests prove model invariants and static dependencies only. Trusted adapters
must validate all-day query membership, duplicate/provider identity, actual
enumeration coverage and freshness. PR-04 owns policy isolation/filtering/revocation;
PR-19/20 owns authenticated context and trusted single-use approvals; later writers
must recheck current policy and preconditions immediately before dispatch. Unknown
revisions never authorize an unconditional write. Destination privacy/ownership,
atomic provider writes, uncertain-create recovery, oldest-OS/runtime behavior and
home-Mac setup remain unverified at their existing gates. Exact committed local and
hosted evidence belongs in [progress](../../implementation/progress.md) and the PR.
