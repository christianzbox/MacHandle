# ADR-0027: Independent Reminders reads and field-scoped MCP tools

Date: 2026-10-28. Status: implemented for work package 22 review; live MCP activation gated.
Requirements: [PR-22](../../product/master-spec.md#pr-22--reminders-provider-and-read-operations),
[§9](../../product/master-spec.md#9-reminders-integration),
[ADR-0024](0024-mcp-connection-identity.md), [ADR-0026](0026-calendar-mutation-journal.md).

## Independent provider and local opt-in

Add immutable ReminderReadRequest/ReminderSnapshot and separate ReminderDiscovering/ReminderReading
contracts to CoreDomain. Requests contain 1–32 exact account/store/list references; a detail request
contains exactly the item's list. Snapshots reject duplicate, foreign or mismatched items and more
than 1000 records. No EventKit, transport, SQLite or UI type enters these contracts.

EventKitRemindersProvider owns its own lazy store and Reminders authorization; it shares the existing
AppleCalendarProvider infrastructure target, not Calendar grants or runtime state. Only explicit
requestAccess invokes the Reminders permission API. Full Reminders access is required; Calendar
write-only/full access never substitutes. Discovery retains source/account names for local list
selection, plus exact identities. MCP discovery returns selected list names and opaque IDs only.

The native Apple Reminders screen starts off and selects no lists automatically. Enable requests
permission/discovery, selection authorizes only local reads, and search matches permitted titles.
Details optionally include notes through an explicit local toggle. Local read policy and generations
are checked around suspension. Disable, changed query/selection and refresh clear output and cancel
pending reads; late grant/read results cannot restore access. Activation refresh/store-change hints
revalidate data without requesting permission. If refresh interrupts an existing operation, the UI
clears results and asks for a new refresh instead of reusing a stale result. No saved selection,
external grant, Google synchronization or reminder write is enabled by local opt-in.

## Async EventKit and semantic limits

EventKit fetches reminders asynchronously. Its cancel API suppresses completion, so our locked,
single-resolution continuation bridge explicitly resumes on cancellation and ignores late callbacks.
A private fetch token remains in the provider actor. A ten-second deadline cancels stalled requests;
at most four fetches are active per provider. Callback objects are reduced synchronously into immutable
records; EventKit objects never cross to consumers. Reads recheck OS access, exact inventory/store and
store-change hints after suspension. Missing detail items remain unknown local absence, not deletion.

Only requested title/notes/due/completion/recurrence properties enter domain output. EventKit itself
fetches full native objects; its API offers neither field-level fetch projection nor server pagination.
We cap processing at 1000 records and mark provider-limit coverage partial; this does not bound the
native array allocation. Selected-list scoping, one-item detail lookup, deadlines and active-request
limits bound what we control. Search may miss matches beyond the cap and never claims completeness
then. Engineering owns any richer pagination/search strategy; revisit with large isolated lists before
promising full-list search. Oversized requested text and malformed components fail closed.

Due-date normalization preserves a date-only value separately from local date/time and keeps nil time
zone floating. Named zones are retained; ambiguous or nonexistent DST local times are not converted
into invented instants. Invalid/incomplete/non-Gregorian components fail instead of becoming “no due
date.” Completion has a separate optional completion instant. A new recurrence field reports presence
only (recurring/notRecurring), under explicit field permission; rules are not expanded, inferred or
converted into Calendar events. Alarm, recurrence-rule editing and completion mutations belong to
package 23. Revision remains unknown; this read path does not issue mutation preconditions.

## Paired connections and MCP projection

MCPRemindersAdapter depends only on MCPServer, domain, policy and MCPConnections. It requires a
trusted ConnectionReadLease; there is no wire identity selector or fallback session. Authorization
callback defaults to unknown. The existing lease enforces cancellation/budgets and invalidation;
new audit operation names distinguish Reminder discovery/search/detail without content.

SavedReminderGrant is read-only and independent from Calendar grants. Settings envelope v2 stores
optional reminder candidates; legacy v1 records decode to no Reminder grants, and v1 with Reminder
candidates is rejected. Future versions remain rejected. Restoring settings does not restore a paired
session or enabled channel. Pairing requires current OS access for every resource family actually
selected, rather than requiring Calendar access for a Reminders-only connection. Any OS/config change
still invalidates the existing channel, conservatively requiring a new local review.

Three tools are registered in the synthetic-only helper: list_reminder_lists, search_reminders and
get_reminder. Search requires explicit fields and title permission for a nonempty query; projection
happens before matching/counting so hidden notes cannot affect results. Detail refetches the exact
item under current detail permission. Opaque handles are adapter-local, expire after five monotonic
minutes, and are bounded to 512. A detail result checks expiry again before queued output. All output
is bounded to 16 KiB and revalidates current OS, lease and policy before encoding/transmission.
Missing detail output says notObserved and absenceProvesDeletion=false. Provider freshness remains
local-cache/unknown, never an invented upstream guarantee. Content is inert untrusted data.

The executable still requires --synthetic, now with eleven tools (four mock, four Calendar, three
Reminders). No real provider, signing credential or permission prompt is linked into its composition.
The app's local provider opt-in and a signed live MCP broker are separate capabilities. Production MCP
remains blocked on package 19's owned identity/native pairing/current OS/actual-client gates.

## Alternatives, evidence and follow-up

We rejected reusing Calendar permission/selection, searching hidden provider fields, treating nil due
zones as system time, assuming cancelled callbacks will arrive, and claiming a capped search is
complete. We retained the existing provider target to reuse EventKit observation code without adding
another public infrastructure dependency; the Reminders actor and contracts remain independent.
We use additive v2 candidate settings rather than implicitly expanding old Calendar grants.

Synthetic tests cover opt-in/selection, cancelled/late prompts and reads, revocation and queued output,
permission/field isolation, exact refetches, foreign/expired handles, due semantics, partial absence,
continuation cancellation and legacy settings. Subprocess/official SDK checks exercise all three
Reminder tools and hidden-field canaries. Native builds verify the new usage description. Automated
provider tests use no real EKReminder objects or personal accounts. Full staged/final-head results
belong in progress/PR, separate from hosted CI and live evidence.

Engineering/maintainer retain signed TCC/sandbox/minimum-OS and explicitly authorized synthetic-list
runtime acceptance, actual MCP clients and large-list behavior. Trigger: approved identity and isolated
fixture setup before live MCP exposure. Native opt-in code is implemented but real permission/data
behavior is not claimed verified. Package 21's live writer remains closed; Reminders changes belong
to package 23 and Notes still requires package 26's feasibility gate.

## Official sources reviewed 2026-10-28

- [Apple retrieving events and reminders](https://developer.apple.com/documentation/eventkit/retrieving-events-and-reminders) — asynchronous predicate fetch, cancellation token and exact item lookup.
- [Apple cancelFetchRequest](https://developer.apple.com/documentation/eventkit/ekeventstore/cancelfetchrequest(_:)) — cancellation suppresses completion.
- [Apple dueDateComponents](https://developer.apple.com/documentation/eventkit/ekreminder/duedatecomponents) — floating zones and date-only components.
- [Apple current access migration](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels) — macOS 14+ full-access usage descriptions.
- [Apple Reminders usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremindersfullaccessusagedescription) — purpose string for full Reminders access.
- [MCP tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) — schemas, content and tool boundaries; existing pinned/modern compatibility remains tested.
