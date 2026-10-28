# ADR-0023: Policy-filtered Calendar read adapters

Date: 2026-10-28. Status: implemented for work package 18 review, synthetic execution only.
Requirements: [PR-18](../../product/master-spec.md#pr-18--mcp-read-operations),
[§4](../../product/master-spec.md#4-security-and-permission-model),
[§8](../../product/master-spec.md#8-mcp-and-ai-integration).
Builds on [ADR-0009](0009-permission-policy-engine.md),
[ADR-0012](0012-calendar-reads-availability.md) and [ADR-0022](0022-mcp-server-foundation.md).

## Decision and trust boundary

Add MCPCalendarAdapter, depending only on MCPServer, CoreDomain and PermissionEngine.
The protocol target remains dependency-free. The adapter receives one already-bound
PolicySession, an explicit selected-calendar set, CalendarReading and a current OS-status
closure. It cannot select another connection, configure grants, prompt for access or
write to sources. CalendarReadAdapter is internal; the only executable composition is a
package-visible fixed synthetic fixture. The helper still requires `--synthetic` and
imports no EventKit, app, credential, database or Google code.

The fixture alone creates a synthetic policy authority, grants read operations on one
invented calendar and intentionally over-returns hidden fields/another calendar. This
exercises filtering without granting real access. A future trusted broker must establish
identity and bind a fresh session independently; neither tool arguments, metadata, names,
process presence nor handles authenticate a client. There is no installed live factory,
broker IPC, listener, automatic connection or personal configuration change.

Expose package-only registration/JSON/input/result contracts so a separate adapter can
register tools without importing providers into the protocol module. Compiler/dependency
checks still reject external registry/session/adapter/factory construction. The small
schema vocabulary now covers bounded integers, Unicode-scalar-length strings and unique
bounded string arrays/enums. Unknown keys and invalid shapes fail before tool execution.
Arbitrary JSON Schema references or caller-supplied schemas are not accepted.

## Tool contracts and data flow

| Tool | Policy and provider scope | Returned data |
| --- | --- | --- |
| list_calendars | Evaluate discover separately for trusted selected references; fetch metadata only when something is allowed, filter with each receipt and revalidate all receipts | Names and opaque calendar handles for permitted resources; observation metadata |
| get_availability | Exact nonempty calendar/window selection, checkAvailability, time/occupancy fields only; provider requested detail fields are empty | Clipped busy/tentative/unknown blocks and observation, no calendar/event IDs or content; absenceProvesFree is always false |
| search_calendar_events | readSummary plus structural fields and optional title; match only after trusted projection; nonempty query requires title visibility | Bounded occurrences, opaque handles, permitted titles when requested, time/status/occupancy, observation and explicit truncation |
| get_calendar_event | Resolve a handle, re-read its calendar within the original search window under readDetails and explicit fields, match the full occurrence reference | Current permitted fields and explicit found/notFoundInWindow/unknown status; no cached event content |

Search is case-insensitive literal matching against visible titles only. Location/notes
never affect matching or counts. Missing/unfetched title values cannot prove no matches:
a nonempty query fails closed if any returned occurrence lacks a fetched title; a fetched
null is known empty. An empty query can enumerate structural data without fetching titles.
Field values distinguish fetched null, notFetched and notAuthorized. Resource strings
are data, never instructions, tool metadata, URLs to fetch or approval statements.

No provider/store/account/local IDs, series IDs, recurrence anchors or revisions are
serialized. The explicit projection preserves timed instants/zone and all-day civil
start/exclusive-end/zone. Inputs use integer UTC epoch milliseconds; returned instant
intervals/observations use epoch seconds (fractional values allowed). No local machine
zone conversion is implicit. All-day overlap, exact coverage, occurrence count and
unambiguous/unique occurrence references are checked even for an over-returning provider.

## Bounds, uncertainty and revocation

- At most 32 selected calendars, a nonempty half-open window of at most 400 days and
  10,000 provider occurrences. Global discovery inventories over 10,000 fail closed.
- Search returns at most the requested 1–100 events. Truncation is explicit and changes
  complete coverage to partial/outputLimit; existing partial/unknown source evidence
  remains intact. There is no pagination cursor: narrow the window when truncated.
- Availability over 1,000 blocks fails; it is never silently truncated into apparent free
  time. Provider failures stay errors. Missing detail is only notFoundInWindow for complete
  local coverage; partial/unknown reads yield unknown. Local-cache freshness stays explicit.
- Calendar handles are random UUIDs scoped to the adapter lifetime. Event handles retain
  only reference/window metadata, expire after five monotonic minutes and are capped at
  512 per adapter. Expired entries are pruned on search/detail. Restart/another adapter
  cannot resolve a handle. They are names, not bearer authorization; every lookup rechecks
  the session/operation/fields. Repeated searches may issue new handles; exhaustion returns
  an error until expiry/restart. No result cache or database is added.
- Names are limited to 1 KiB and field values to 8 KiB; the complete structured read result
  is capped at 16 KiB before its duplicate text encoding. Larger results fail explicitly;
  content is not silently shortened. Existing 64 KiB frames, four pending calls, bounded
  parser/history, cancellation, EOF/signal handling and two-second writer deadline remain.
- Current OS access and policy are checked before provider work, after suspension and
  after projection. A result carries a private revalidation closure checked again at
  protocol delivery; stale/revoked results become a fixed tool error without their data.
  Cancellation suppresses late provider results. No raw errors, queries or resource data
  enter logs. Once bytes are dispatched they cannot be recalled; OS state can change
  after a check. These checks do not claim an atomic OS or transport transaction.

## Compatibility, alternatives and consequences

The official [modern tools contract](https://modelcontextprotocol.io/specification/2026-07-28/server/tools)
and [legacy tools contract](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
were refreshed on 2026-10-28. Keep explicit input/output schemas, text plus structured
results and tool execution errors. Fixed tool listings convey no grants. The existing
1.26.0 legacy and 2.4.0 pinned-modern/auto official SDK matrix now exercises all four reads
and privacy assertions; both protocol profiles also run through real subprocess tests.
The [developer procedure](../../development/mcp-calendar-reads.md) reproduces this evidence.

Direct provider/PolicyAuthority access in the protocol target was rejected to keep parsing
and transport isolated. Raw IDs would simplify lookups but expose internal identity domains;
opaque bounded handles cost state and need rediscovery after restart. Cached details would
avoid a read but risk stale exposure; refetching costs bounded provider work. Searching all
raw fields and filtering afterward would leak through matches; projected-title matching
limits search capability deliberately. Silent truncation/paging would hide uncertainty;
explicit limits trade convenience for bounded output and honest coverage. A general schema
engine remains unnecessary for this small input vocabulary; revisit before complex tools.

## Remaining gates and owners

No live external Calendar reads are activated. Engineering/maintainer own package 19
identity, persistent grants, channel binding and revocation, plus ADR-0022's signed broker
reachability/mutual-peer/sandbox/minimum-OS/client acceptance after approved identity setup.
Trusted future composition must connect current OS observation/invalidation and cancellable
provider deadlines; only immediate fixed fixtures ship here, not arbitrary remote handlers.
Real TCC/EventKit reads and the home Mac remain unverified. Actual client configuration,
account setup, release signing and public distribution are not part of this package.
Google's independent live-activation ledger remains open. No milestone C completion,
security audit or authenticated integration is inferred from these tests.
