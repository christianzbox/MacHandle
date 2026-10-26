# ADR-0012 — Bounded Calendar reads and availability

Date: 2026-10-26. Status: work package 07 implemented for review; not merged.
Prerequisite: GitHub PR #7 merged at `ab345134daa94f4a4a195ae709e94d6f3d29c7e2`
on 2026-10-26 19:58:42 UTC. Requirements: specification PR-07 and §§4, 7, 20.

## Context and evidence

Discovery supplies local identities and selection, not read authority. CalendarReading
must remain independent of CalendarWriting, synthetic preview policy and future Google/MCP.
The pinned SDK documents that EventKit's
[event predicate](https://developer.apple.com/documentation/eventkit/ekeventstore/predicateforevents(withstart:end:calendars:))
uses all calendars for nil selection and truncates windows beyond four years. Its
[occurrence date](https://developer.apple.com/documentation/eventkit/ekevent/occurrencedate)
is the original recurring occurrence anchor even when an instance moves. SDK declarations
also document synchronous event enumeration and default-zone floating/all-day dates.
These contracts were inspected locally; they do not establish live provider fidelity.

## Decision

1. Require nonempty exact provider/store/account/calendar identities, resolve them
   against current calendars before and after enumeration, and reject missing or
   ambiguous identities. Pass an explicit nonempty calendar array to EventKit.
2. Reject windows over 400 fixed 24-hour days or outside supported Gregorian bounds.
   Collect at most 10,000 occurrences. A further callback stops enumeration and marks
   coverage partial/providerLimit. The UI displays at most 100 rows and asks users to
   narrow the range. Bounds protect responsiveness and avoid silent four-year truncation;
   they are not claims about EventKit's internal memory use or interruptible I/O.
3. Check real full OS access before/after query and after normalization. Detect store
   notifications/default-timezone changes during the query and return unavailable.
   Keep the synchronous enumeration callback and primitive accumulator in one static
   synchronous scope; no EventKit objects cross actor boundaries. Only notification
   state uses a lock-protected Sendable wrapper. Cancellation discards late results.
4. Normalize to half-open intervals, preserve timed zones and all-day civil exclusive
   ends, and use Gregorian zone resolution for DST days. Reject invalid/skipped civil
   dates. Identity uses local item ID plus original occurrence anchor; missing anchors
   and revisions remain unknown. Do not invent series IDs, cross-Mac IDs or revisions.
   Sort returned occurrences chronologically. This materializes EventKit occurrences;
   it does not implement recurrence expansion or cross-provider reconciliation.
5. CalendarReading accepts requested detail fields; its convenience overload requests
   none. Availability reads do not access title/location/notes properties in adapter
   code. EventKit can internally materialize full objects, so OS-level field isolation
   is not claimed. No attendees, links or other detail properties are exported.
6. CalendarReadStore owns a private real PolicyAuthority, distinct from preview actors.
   Each explicit Read binds fresh local read-only operation/field grants to current
   selection, checks OS access, obtains a permit, reads, rechecks state after every
   suspension, revalidates the permit and filters data. A final OS check precedes
   publishing filtered content. The root creates one reader per access store; access
   changes synchronously clear its retained result and invalidate pending generations.
   No view/client receives the authority, session or provider. No mutation is granted.
7. Availability omits cancelled/known-free events, clips occupied/uncertain intervals
   to the request, and treats unknown status as uncertain. Keep overlapping blocks
   separate rather than inventing precedence. Policy output removes calendar/event IDs
   and all details. Empty/partial/local-cache observations never prove free time or
   authorize destructive reconciliation. Complete means bounded local enumeration only.
8. Results live only in memory. Mode/date/selection/access changes, refresh, Clear Results
   and disable clear them; quit resets opt-in. A running synchronous provider query may
   finish before cancellation is observed, but its late content cannot be published.
   No content, raw error strings, IDs or query logs enter preview activity or diagnostics.

## Alternatives and consequences

- Unbounded reads or nil predicates are simpler but silently broaden selection or lose
  coverage. Explicit bounds and failure states require users to narrow large requests.
- Treating local success as upstream completeness would make availability and future
  deletion unsafe. Preserve local-cache freshness independently of coverage.
- Fetching all detail properties then relying only on UI hiding would unnecessarily
  copy sensitive fields. Adapter minimization plus trusted projection is defense in
  depth; synthetic over-return tests verify projection independently.
- Reusing preview policy is convenient but mixes simulated and real OS authority.
  Separate injection costs a small local service and keeps the trust boundary explicit.
- A persistent event cache would improve repeat-read speed but needs retention,
  migrations and privacy decisions outside this package. No persistence is introduced.
- Converting all-day events to fixed UTC durations loses civil/DST meaning. Resolve
  original civil endpoints in their captured zone and fail on unrepresentable dates.

## Evidence, limits and follow-up

Nineteen new synthetic tests bring the suite to 84 Swift tests. They cover normalization,
selection, partial/unknown/failure states, hidden-field projection, current OS checks,
late-result rejection and read-only policy. An eighth negative compiler probe rejects
permission prompting through CalendarReading. A disposable native synthetic harness
verified availability/title/detail modes, clearing, partial messaging and scroll layout.
The adapter is compiled, not exercised against a real event store. Exact final-head
standard gates and hosted status belong in the review PR and [progress](../../implementation/progress.md).

Live TCC grant/deny/revoke, sandbox reads, actual recurrence expansion and Calendar
account behavior remain unverified. Reason: no authorized isolated account/device in
this task. Owner: maintainer and Calendar provider work; trigger: explicit isolated
fixture authorization before milestone A acceptance, revisited in work package 13.
Home-Mac, Intel/oldest-OS runtime and release signing remain separate gates. OS/provider
changes can occur immediately after any check; returned data cannot be recalled and
no atomic OS transaction or security audit is claimed. No event writes, external
connections, tokens, sync, MCP, persistence or production readiness is delivered.
