# ADR-0004: Deployment baseline and Apple provider constraints

Date: 2026-10-23 (America/Detroit). Status: accepted design for PR-02 review;
API research and compile evidence only. No provider or OS permission test.
Supersedes ADR-0001's provisional deployment-floor decision, not its runtime gates.
Requirements: master specification §§4–6, 7.7, 9–10 and 13.4.

## Decision and evidence

Keep **macOS 14.0** as the implementation target, Swift 6 language mode and the
existing Swift tools 6.2 manifest. Keep the exact build tuple in
`Config/Toolchain.env`: Xcode 27.1 (27A9275), Swift 6.4, macOS SDK 27.0.
Apple's [Xcode support table](https://developer.apple.com/xcode/system-requirements)
(rechecked today) lists Xcode 27.1 on macOS 26.6 or later, with Swift 6 and deployment
targets including macOS 14. Development-host requirements do not raise the app floor.
No toolchain, global Xcode selection, target or entitlement changed in this PR.

[EventKit migration guidance](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels)
places the new access levels at macOS 14. The SDK headers agree.
[Service Management](https://developer.apple.com/documentation/servicemanagement/smappservice)
is available from macOS 13. Our disposable Swift 6 typecheck passed for macOS 14
arm64 and x86_64 using the selected APIs; see [PR-02 evidence](../../implementation/prs/pr-02.md#evidence-and-experiments).
This supports the API choice, not an advertised oldest-OS or Intel runtime guarantee.
PR-06/22/24 and PR-30 must test signed builds on supported OS/hardware before claims.

## Permission and API matrix

All references below were inspected on 2026-10-23. Apple documentation JSON was
used where its HTML renderer exposed only a JavaScript placeholder. The matching
SDK headers/typechecker independently constrain availability.

| Provider | OS boundary and later configuration | Trusted application boundary / owner |
| --- | --- | --- |
| Calendar | `requestFullAccessToEvents()` for reads; `NSCalendarsFullAccessUsageDescription`; sandbox calendar entitlement when implemented | PR-06/07: opt-in before request, selected sources/calendars, explicit availability fields. Write-only cannot supply source reads. PR-21 owns approved writes. |
| Reminders | Independent `requestFullAccessToReminders()`; `NSRemindersFullAccessUsageDescription`; calendar entitlement for sandboxed EventKit access, to validate with signed synthetic setup | PR-22: separate opt-in/list selection; Calendar grant never substitutes for Reminders grant. PR-23 owns approved writes. |
| Contacts | `CNContactStore` authorization; `NSContactsUsageDescription`; `com.apple.security.personal-information.addressbook` when implemented | PR-24: selected fields/subsets enforced locally. PR-25: explicit changed fields and approval; no Google export. |

Apple's [event-store guide](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)
states there is no read-only EventKit authorization. Full access allows reads and
writes; write-only events expose no readable event inventory. Entitlements permit
capabilities, usage descriptions explain requests, and TCC grants OS access: none
is a per-connection policy. Sync receives only a source-read interface even though
the provider process can possess broader OS authority. Reject denied, restricted,
not-determined and write-only-as-read states; unknown future states fail closed.
Recheck authorization and selection at operations and after lifecycle changes.

Exact configuration references:
[Calendar full-access description](https://developer.apple.com/documentation/bundleresources/information-property-list/nscalendarsfullaccessusagedescription),
[Reminders full-access description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremindersfullaccessusagedescription),
[calendar entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.calendars),
[Contacts entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.addressbook).
These are implementation requirements for their owning PRs, not entitlements added now.
No Contacts prompt is justified merely to read calendar events.

## Identity, completeness and domain consequences

- EventKit's [local item identifier](https://developer.apple.com/documentation/eventkit/ekcalendaritem/calendaritemidentifier)
  can be lost after a full calendar sync. Its
  [external identifier](https://developer.apple.com/documentation/eventkit/ekcalendaritem/calendaritemexternalidentifier)
  can be duplicated across calendars; recurring instances share it, and Exchange
  has cross-device differences. Namespace references by provider/account/calendar;
  neither identifier is a universal primary key or a mutation version.
- [Original occurrence date](https://developer.apple.com/documentation/eventkit/ekevent/occurrencedate)
  survives a detached instance's start-time change. Preserve original recurrence
  anchor separately from current start/end, provider IDs, timezone and all-day date
  boundaries. Floating occurrences use the default timezone. PR-07/13 must test
  exceptions, series edits/moves, DST and resync before settling reconciliation keys.
- Prefer materialized occurrences in the specification's initial 30-day-past /
  365-day-future horizon. This bounds cost and complexity but needs horizon rollover
  and exception recovery. The [EventKit range predicate](https://developer.apple.com/documentation/eventkit/ekeventstore/predicateforevents(withstart:end:calendars:))
  truncates ranges beyond four years. Never pass nil calendars as shorthand for a
  failed selection; it means all calendars. PR-07 owns explicit coverage metadata.
- A completed local EventKit fetch is not proof that an upstream iCloud/Exchange
  sync is current. Distinguish empty, partial, unavailable, revoked and unknown
  freshness. PR-11/14 must gate deletion on validated coverage/mappings and recovery
  controls; absence alone is insufficient. No universal server revision is assumed.
- Reminder due dates are date components, with optional time/timezone, not always
  instants or alarms. PR-03 preserves this distinction; PR-22/23 verifies recurrence,
  completion, writable-list limits and supported metadata without private APIs.

[Contacts framework](https://developer.apple.com/documentation/contacts) supports
specific predicates and `keysToFetch`, not arbitrary compound predicates. Fetch
only authorized necessary properties; return a separately filtered domain value.
Formatting descriptors may fetch extra fields, so authorize them explicitly.
[CNContactStore](https://developer.apple.com/documentation/contacts/cncontactstore)
recommends off-main-thread I/O and refetching cached objects on change notification.
Keep framework objects inside provider isolation and pass immutable domain values.

A [contact identifier](https://developer.apple.com/documentation/contacts/cncontact/identifier)
is device-local. Unified contacts can represent linked records; do not treat a
unified display value as proof of one writable underlying record/container.
PR-24/25 must resolve selected subsets and writable targets conservatively, refetch
before mutation and reject ambiguous identity/version comparisons. Unfetched fields
are not empty values to erase. Contact notes and unrestricted address-book fetching
are not prerequisites and receive no speculative entitlement.

[Limited Contacts authorization](https://developer.apple.com/documentation/contacts/cnauthorizationstatus/limited)
is not available to native macOS in the inspected SDK; a negative typecheck confirmed
this. Do not promise iOS contact-picker OS isolation. MacHandle's supported contact
subsets are an application policy, with provider tests still required.

## Alternatives, tradeoffs and gates

macOS 13 would need legacy EventKit authorization paths and duplicate testing;
raising to the development host's OS would exclude users without a demonstrated
requirement. Keep 14 and require availability checks for later APIs. Building both
architectures is useful evidence but cannot replace native runtime tests.

A universal resource/ID blob would conceal field, recurrence and completeness
semantics. PR-03 instead defines small typed values and separate read/write contracts;
no EventKit/Contacts imports in domain. Provider snapshots should describe coverage,
observation time and failure state without pretending to prove upstream freshness.

| Unresolved evidence / blocker | Owner and revisit trigger |
| --- | --- |
| Oldest OS and Intel runtime, signed TCC grant/deny/revoke, real sandbox enforcement | PR-06/22/24 with authorized synthetic resources; PR-30 release matrix. Do not advertise compatibility from typecheck alone. |
| Recurrence identity across provider resync/moves; reliable mutation preconditions | PR-07/13/21 with isolated provider fixtures; block destructive reconciliation on ambiguity. |
| Contact linked/container subsets and permitted fields; stale writes | PR-24/25 before exposing those capabilities. |
| Provider concurrency and non-atomic check/write races | PR-07/21/23/25: serialized provider execution, refetch and conflict handling; do not claim a server transaction from local checks. |

No product capability is dropped. These are later acceptance gates, with researched
constraints sufficient for PR-03's pure domain work after PR-02 merges.
