# ADR-0011 — Calendar authorization and local discovery

Date: 2026-10-26. Status: work package 06 merged in GitHub PR #7 at
`ab345134daa94f4a4a195ae709e94d6f3d29c7e2` (2026-10-26 19:58:42 UTC).
Event reading extends this boundary in [ADR-0012](0012-calendar-reads-availability.md).
Predecessor GitHub PR #6 merged at `12b4ebf80816dcd307673a64085d00f88bb20981`
on 2026-10-26 19:18:26 UTC. Requirements: legacy PR-06 and specification §§4, 7, 12, 20.

## Evidence and API decision

Use supported EventKit full Calendar access on macOS 14+, with the pinned compiler.
Apple's [event-store guide](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)
and [Calendar entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.calendars)
were rechecked on 2026-10-26, along with the SDK headers. EventKit has no read-only
OS grant: full access includes reads/writes, while write-only cannot provide an
actual calendar inventory. The native opt-in screen and
`NSCalendarsFullAccessUsageDescription` disclose this distinction. Add only the
Calendar sandbox entitlement; no Reminders/Contacts description, network capability,
login registration or usage prompt at launch.

## Implemented boundaries

- CoreDomain adds CalendarDiscovering, CalendarAccount, a validated CalendarCatalog,
  and explicit available/access/incomplete/unavailable results. IDs retain provider,
  store, source/account and calendar identity; duplicate or foreign catalog identities
  fail validation. Display names never resolve identity. Available means coherent
  **local metadata**, not complete event coverage or upstream freshness.
- AppleCalendarProvider depends only on CoreDomain and contains all EventKit imports.
  Its actor lazily creates EKEventStore after opt-in, serializes metadata access and
  returns immutable values. It rereads authorization after the request callback and
  before/after discovery; callback success alone is not authority. Unknown states
  fail closed. It never fetches events, writes anything or calls a remote service.
- MacHandleApplication depends on contracts/policy, not the concrete provider. Its
  CalendarAccessStore starts disabled with no provider calls. Explicit Enable may
  request full access only from not-determined/write-only. Denied/restricted users
  receive System Settings guidance; refresh never presents another prompt.
- App composition injects this real provider separately from the existing synthetic
  policy actors. Views receive observable state and actions, never EventKit objects
  or PolicyAuthority. Local selection is configuration data, not a policy grant,
  bound connection, approval token or event-read capability. Google/MCP remain off.

CalendarDiscovering is deliberately narrower than CalendarReading, which also requires
occurrence reads. Package 07 will implement the latter and map metadata to scoped
observations; this package does not fake event support to satisfy that protocol.

## Lifetime, races and uncertainty

Account/calendar names and selections live only in memory. Enable must be repeated
after quitting, even if macOS retained a grant. Disable clears names/selections but
cannot revoke OS permission or dismiss an OS prompt already displayed. A generation
check after each suspension prevents a late grant or metadata result from re-enabling
discovery. Disable during authorization prevents a subsequent prompt; during a prompt
it prevents the subsequent inventory read. Cancellation also clears pending results.

Refresh hides the previous inventory and exposes no selected calendars until it
completes. A coherent refresh retains only exact surviving selected IDs. Revocation,
incomplete/unavailable results, disable or cancellation clear selections; restored
access never automatically reselects them. Unknown IDs cannot be selected.

Refresh on foreground/reopening while enabled and on EventKit store-change signals.
The bounded notification stream contains only Void, never EventKit data; a small
lock-protected Sendable observer wrapper owns token cleanup. Window task cancellation
removes its observation. Concurrent refreshes invalidate older results and coalesce
into a new observation. There is no background synchronization or polling daemon.
Future provider operations still need their own current authorization/policy rechecks;
notifications cannot prove atomicity with external account changes.

EventKit metadata enumeration does not return per-source network-health evidence.
A coherent empty local list is labeled only “No calendars returned locally”; it never
proves upstream emptiness or permits destructive reconciliation. Inconsistent IDs or
a changed store identity return incomplete; unavailable is retained in the contract
for explicit provider failures. Do not invent remote availability from this API.

## Alternatives and consequences

- Requesting permission at launch would violate opt-in. A separate local Enable action
  gives an explanation before TCC and keeps an existing OS grant from loading metadata
  on a new session automatically.
- Reusing sample policy authorities would promote simulated full access into live
  authority. Separate provider composition prevents that; future connection grants
  require an independently trusted path in package 07/18/19.
- Persisting selections now would require storage/versioning/recovery before package
  10. Memory-only choices cost a repeat selection after restart, explicitly disclosed.
  Package 10 owns revisiting persistence; no requirement is abandoned.
- Global EventKit objects or framework types in views would obscure concurrency and
  dependency boundaries. The actor costs adapter code but keeps framework lifetimes
  local. Dependency/import checks preserve these constraints.
- Treating missing calendars as “all calendars” or treating uncertain reads as an
  authoritative empty set is unsafe. Fail closed and require explicit selection.

## Verification and remaining gates

Fifteen application tests cover opt-in/no eager calls, authorization distinctions,
identity validation, selection/removal, uncertain results, revocation, overlapping
refresh, disable during authorization/prompt/discovery, cancellation, new sessions,
and observable selection updates. Two adapter tests exercise SDK status mapping and
a synthetic notification without loading a real store. Together with prior tests,
there are 65 Swift tests and 13 Python repository tests.

The default locally signed universal Debug app launches and shows the off-state opt-in
screen via Cmd-5. Its built Info.plist and signed entitlements contain the intended
Calendar capability and explanation. A disposable native harness injects synthetic
metadata for selection and denied/incomplete/unavailable/empty screens. No harness,
screenshots or real names are committed. Native rendering inspection is separate
from unit-test and full-gate evidence in [progress](../../implementation/progress.md).

Live TCC grant/deny/revoke and real sandbox discovery remain **unverified**: this
session has no authorized isolated Calendar account/device, so no real prompt or
metadata access was exercised. These are package 06/07 integration acceptance gates,
owned by the maintainer/provider work, to revisit with an explicitly authorized
synthetic-account device before live capability claims. Home-Mac, macOS 14/Intel
runtime and distribution signing remain package 30 release gates. Build success,
synthetic injection and configured entitlements are not proof of those behaviors.
