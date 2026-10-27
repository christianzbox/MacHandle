# ADR-0018 — Bounded occurrences and canonical time

Date: 2026-10-27. Status: work package 13 implemented for review; synthetic acceptance
only. Requirements: specification PR-13, §§7.6–7.9 and 20. Prerequisite GitHub PR #13
merged at 1d265050f0e12aa21847b26875e32e12c0d13f4b, 2026-10-27 20:50:32 UTC.
This extends [Calendar reads](0012-calendar-reads-availability.md), supersedes the
content-v1 timezone convention in [planning](0016-pure-reconciliation-planner.md)
and extends [executor](0017-synchronization-executor.md) timestamp support.

## Decision and alternatives

Use EventKit's selected, bounded predicate to materialize occurrences, then export
individual Google events without recurrence rules. Keep the existing 400-day/10,000-event
read bounds and local-cache freshness. CalendarSyncHorizon is a pure planning helper:
given an explicit clock and timezone, use Gregorian local midnight 30 days ago through
local midnight 365 days ahead, exclusive. Calendar-day arithmetic handles DST and leap
years; it is not 395 fixed 24-hour periods. The helper is not an automatic scheduler or
live connection. Existing local availability UI coverage is unchanged.

Implementing an independent RRULE evaluator would duplicate EventKit and create another
exception/timezone model. Copying series rules into Google would require proving two
providers' expansion semantics and editing matching exceptions. Bounded materialization
instead gives each observed occurrence its own durable remote ID, at the cost of bounded
coverage and more events. Instances outside the window are retained, never cleaned up
merely because the horizon advanced. Long events crossing a boundary remain whole.
Scheduling horizon refreshes belongs to package 15.

## Provider identity and ambiguity

Apple documents [occurrenceDate](https://developer.apple.com/documentation/eventkit/ekevent/occurrencedate)
as the original scheduled date, unchanged when a detached event's start changes.
The pinned SDK EKEvent.h additionally documents floating/all-day occurrence dates in
the default timezone. Normalize timed anchors as exact instants and all-day anchors as
civil dates in the captured default zone. Mutable start/end remain separate. A simulated
zone change therefore supplies the same all-day dates expressed in the new default
zone; reinterpreting old cached Date values in a new zone is not valid. The provider
already rejects a zone/store change during enumeration.

CalendarEventNormalization now validates the materialized batch. Duplicate references,
missing recurring anchors, or mixed single/timed/all-day anchor families for the same
local calendar/item fail with ambiguousIdentity; no first/last-wins exception merge.
The planner applies the family check across current observations and durable mappings,
so converting a known series between timed/all-day/single cannot silently create another
remote copy. Normal occurrences, moved exceptions and explicit cancellations retain their
original anchor. Missing instances are not invented or converted into cancellations.

[calendarItemIdentifier](https://developer.apple.com/documentation/eventkit/ekcalendaritem/calendaritemidentifier)
is local and may change on full sync. Its external counterpart is shared by recurring
instances but can also be duplicated across imported/shared calendars. Neither is a
universal matching proof. Retain the existing provider/store/account/calendar/item/anchor
identity key, including its version. Do not infer a series ID, match by title/current
start, or claim detached local IDs always remain stable. Calendar moves change scope;
missing selected calendars fail, and unverified continuity blocks planning. A change
between two different timed anchors or item IDs cannot be diagnosed by the family check:
the trusted adapter must establish continuity before setting sourceIdentity verified.

These are conservative guards, not automated migration. Package 14 owns source account/
calendar migration, missing mapping reconstruction and continuity/recovery policy.
Owner: MacHandle engineering. Revisit when package 14 is authorized and when isolated,
signed EventKit acceptance is available. Until then the executor's default authority
continues to deny live execution; no synthetic freshness or identity flags enter the app.

## Canonical payloads and compatibility

[Google event time](https://developers.google.com/workspace/calendar/api/v3/reference/events)
uses RFC3339 dateTime for timed events and date for all-day events, with an exclusive end.
Send UTC instants or the exact civil dates. No source timezone label or series rule is
exported. GoogleEventTime emits whole seconds when exact, otherwise the formatter's
millisecond representation only if parsing it reproduces the identical Foundation Date.
Unsupported precision or year range is rejected; no rounding tolerance or truncation.
The executor reports invalid time as blocked before preparing that event's intent.
Independent projection round-trip checks remain. Actual Google's fractional precision
acceptance remains a live gate; a mismatching read-back cannot complete a write.

Content fingerprints now explicitly use content-v2: exact instant bit patterns or civil
date components, selected fields and occupancy, excluding display timezone metadata.
Changing Detroit to UTC for an unchanged instant, or moving between zones while retaining
the same all-day dates, causes no update. A real instant/date change still changes the
digest. Occurrence-v1 and calendar-v1 identity digests are unchanged, preserving durable
remote IDs. Proposal IDs bind the new content digest; full previews still include source
timezone metadata and must be re-reviewed if that metadata changes before execution.

Do not reinterpret persisted v1 hashes as v2. An existing active v1 baseline produces a
conflict, and an old pending proposal must not be replayed with a new digest. No automatic
rehash, database deletion or replacement insert is implemented. This deliberate one-time
compatibility boundary is safe while live sync has never been activated; package 14 must
design verified rebaseline/recovery before accepting old state. A test pins the old digest
and proves conflict. The new digest vector is independently derived with Python SHA-256.

## Evidence and limits

Seventeen new tests cover batch identity/exception rules, scoped moves, spring/fall DST,
repeated fall clock times, multi-day exclusive ends, all-day travel, leap-year horizons,
unsupported ranges/precision, canonical comparisons and legacy-baseline conflict.
Provider-normalized synthetic occurrences flow through the real planner, real temporary
SQLite store, internal executor and Google client using a synthetic HTTP transport.
Integration assertions verify three stable IDs across move/cancellation, conditional
update/delete, no extra writes on repetition, fractional round trips, date-only multi-day
payloads across travel, and horizon advancement adding without deleting.

The executor test target alone adds AppleCalendarProvider as a fixture dependency; the
production SyncExecution target still cannot import an Apple provider or writer.
No actual EventKit recurrence expansion, Google account, permissions, Keychain, signed
app, minimum-OS or home Mac was exercised. EventKit's bounded expansion remains provider
behavior, not an independently tested RRULE engine. Future live acceptance must cover
daily/weekly/monthly/yearly rules, detached instance identifier continuity, deleted
exceptions, all-day/type conversion, resyncs, calendar moves and zone changes using
isolated synthetic calendars. Owner: MacHandle engineering, triggered by authorized
setup and signed provider acceptance before package 16 activation.

No production authority, background schedule, destination reconstruction, auto-migration,
source mutation or account activation is added. [Progress](../../implementation/progress.md)
and the review PR separate local, hosted and live evidence.
