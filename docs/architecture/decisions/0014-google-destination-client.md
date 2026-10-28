# ADR-0014 — Google destination ownership and conditional operations

Date: 2026-10-27. Status: work package 09 merged in GitHub PR #10 at `928732effe0985ed34a386cba4367ffd69bdc43c`; live activation,
privacy acceptance and persistence remain gated. Requirements: specification PR-09,
§§7.2–7.9, 13 and 20. Package 08 merged in GitHub PR #9 at
`4d80fabae8b2b3a4482b582a48e974656a02eb3f` on 2026-10-27 19:15:21 UTC.

## Evidence and API fit

The following official method authorization tables were rechecked on 2026-10-27;
each lists `calendar.app.created`. This is documentation evidence, not a live grant:

- [calendars.insert](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/insert)
  creates a secondary calendar; [calendars.get](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/get)
  retrieves its recorded metadata.
- [events.insert](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert),
  [get](https://developers.google.com/workspace/calendar/api/v3/reference/events/get),
  [list](https://developers.google.com/workspace/calendar/api/v3/reference/events/list),
  [update](https://developers.google.com/workspace/calendar/api/v3/reference/events/update) and
  [delete](https://developers.google.com/workspace/calendar/api/v3/reference/events/delete)
  support the required destination primitives. Listing must continue through empty
  pages when a next-page token exists. Update replaces the representation.
- The [version guide](https://developers.google.com/workspace/calendar/api/guides/version-resources)
  defines If-Match and HTTP 412 for concurrent changes. Inserts have no conditional
  modification guarantee. Event IDs use lowercase base32hex; UUID hex fits that set.
- The [error guide](https://developers.google.com/workspace/calendar/api/guides/errors)
  distinguishes quota 403/429, ordinary 403, 412 and transient server failures.

## Decision: one trusted Google implementation boundary

Keep the destination client internal to GoogleAuthorization, alongside authentication.
It has no Domain, EventKit, policy, SwiftUI or database dependency. Its injected
GoogleCalendarSending protocol accepts requests and returns bounded responses, never
tokens. GoogleAuthentication implements it using an authority/generation lease,
coalesced refresh and private credentials. Each dispatch and completion checks the
current session; disconnect cancels tracked requests and discards late completions.
Concurrent refresh waiters cannot dispatch before rotated credentials are persisted.
An API 401 stops authorization and requires sign-in; requests are not replayed after it.
Cancellation cannot undo a remote mutation already accepted by Google.

The client and lease are not exported. Two compile-fail probes verify external app
code cannot construct the client or obtain its lease. No app composition, entitlement,
UI control or source-reader connection changes. This is an explicit activation gate:
even availability times remain sensitive. A future reviewed factory must enforce
privacy, policy, persisted operation identity and single-writer prerequisites.

A separate target with a public token getter was rejected: it would widen credential
access before a consumer needs it. Keeping these cohesive components together avoids
that escape hatch. Splitting targets later may use a narrow package-only transport,
not public bearer-token access. No third-party runtime dependency is introduced.

## Destination and event authority

A destination handle is minted only after the successful create response contains a
valid non-primary ID, expected random ownership marker and observed ETag. The actor
stores its exact ID and session lease. Every operation rechecks calendar metadata.
A matching title, caller-supplied ID, remote marker or another client's handle cannot
select a destination. The marker is continuity evidence, not an independent credential,
Google data-ownership assertion or ACL privacy proof. No CalendarList enumeration,
ACL/sharing changes, primary-calendar alias or calendar deletion is implemented.

Event insert plans bind a random stable event ID, independent operation marker,
destination and desired content before dispatch. Observations bind an owned event
and ETag to an opaque handle. Updates/deletes require that observed ETag, consume the
handle and return conflict on 412. Re-read/replan is required; there is no unconditional
fallback. Remote IDs/markers must match local records. Unmapped events, attendees,
recurring resources, malformed ETags and mismatched ownership fail closed.

Desired payloads contain only summary, description, location, timed or exclusive-end
all-day bounds, transparency, private visibility, ownership properties and disabled
default reminders. Availability defaults to Busy with empty details; an update sends
empty description/location to remove prior detail. There is no attendee/invitation,
conference or attachment input. Requests set sendUpdates=none; this is not a provider
promise of no email under every possible account setting. No recurrence planning,
source conversion or detailed-mode consent UI is implemented; those remain later work.

## Completeness, limits and failure semantics

One operation runs per client actor; concurrent calls fail without overlapping mutation
state. Handles/records are memory-only and capped at 10,000. Pagination requests 100
items, allows at most 100 pages/10,000 events, rejects repeated tokens and duplicate or
unmapped IDs, and returns no partial inventory. Token length is bounded. Successful
pagination is not an atomic snapshot, deletion authorization or sync completion.

All requests use fixed Google HTTPS origin and percent-encoded opaque calendar IDs.
The reused ephemeral URLSession denies redirects, cookies/cache, limits each response
to 64 KiB and uses 30/45-second timeouts. Oversized pages fail closed. Errors carry no
provider text, authenticated URL, account ID or token. No payload logging is added.

Reads retry network failures and 5xx; reads/writes retry explicit quota rejection
(429 or recognized quota-only 403). At most three attempts use 1/2-second exponential
delay plus bounded jitter. Numeric Retry-After up to 30 seconds sets a minimum delay;
longer, invalid or date-form hints stop with rateLimited instead of retrying early.
Other 403, 401, 404/410, 409/412 and malformed responses are not automatically retried.
Writes with transport failure or 5xx return outcomeUnknown. Each retry rechecks the
session and cancellation. No background retry queue is added.

After any attempted event insert, repeating insert with that plan is blocked. An
explicit verifyInsert performs GET and compares ID, ownership, operation, content,
visibility and reminder settings. A collision/404 is not success and does not authorize
a new ID/POST. Calendar creation lacks a caller-supplied ID: one attempted create
blocks further creates on that client, including after a lost response. No title-based
recovery or silent duplicate creation is offered. These in-memory latches are **not
crash-safe or cross-client/cross-Mac protection** and must not be activated as sync.

## Deferred live gates, owners and consequences

- Maintainer/authentication work: developer/OAuth setup and signed sandbox/Keychain/
  isolated-account acceptance. Revisit after the [setup guide](../../development/google-auth-setup.md)
  is completed and live testing explicitly authorized. Nothing live was accessed here.
- Packages 09/16 privacy work: establish a supported account-specific private-calendar
  verification/revalidation flow. The narrow scope cannot inspect ACLs; no supported
  permanent privacy proof has been established. Source transfer stays blocked until
  that gate passes; do not widen scopes or treat visibility=private as ACL evidence.
- Packages 10/14: persist destination/account identity, operation IDs and recovery
  states before dispatch, reconstruct ownership safely, and enforce one writer.
  Revisit when persistence/recovery is authorized. A fresh actor/process must not be
  used as a workaround for unknown outcomes in live operation.
- Packages 11–13: planner, executor, consent projection, durable mutation recovery,
  source completeness and recurrence/time correctness. This client is not that layer.

Synthetic fixtures verify the trusted boundaries and errors. They do not prove Google's
actual account behavior, privacy, notifications, rate-limit timing, signed networking,
real Keychain, minimum-OS/Intel or production approval. Exact local/hosted results and
final commit belong in the review PR and [progress](../../implementation/progress.md).

## Work package 10 persistence follow-up

[ADR-0015](0015-sqlite-persistence.md) adds a separate durable metadata/operation store.
It does not change this client's internal capabilities or wire storage to dispatch.
Snapshots are untrusted recovery candidates requiring remote verification; packages
12/14 own the integration and single-writer recovery before live activation.

## Work package 12 durable bridge

[ADR-0017](0017-synchronization-executor.md) adds a package-only bridge issued from an
already owned session destination. It accepts committed stable operation/event IDs, adds
a mutation marker, rechecks authority per HTTP attempt and verifies writes with separate
reads. No external constructor, bearer getter, calendar reconstruction or app activation
is added. Calendar creation can use a persisted UUID marker; live bootstrap remains gated.

## Work package 14 follow-up — 2026-10-28

[ADR-0019](0019-deletion-safety-recovery.md) adds exact destructive batch approval,
authenticated standby/writer restoration, retained metadata reconstruction, verified
legacy rebaseline/source rebinding and cooperative conditional writer transfer. It
supersedes the earlier statement that these internal recovery contracts are unimplemented.
Unknown writes remain read-only recovery; missing evidence remains intervention. Live
account/source authority, backup acquisition/UI, signed privacy, actual Google conditional
behavior and two-Mac acceptance remain engineering gates before package 16 activation.
