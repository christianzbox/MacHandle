# Privacy model

Current implementation includes merged opt-in Calendar discovery and work package 07
local event/availability reads for review. Names, selections and results remain in
memory. Explicit Read defaults to availability; title/detail modes are separate choices.
No events are modified. Read results clear on access, selection, field or window changes. Enable explains and may request full Calendar OS access; launch never
requests permission or loads metadata. Disable/revocation clears displayed metadata,
and quit resets local opt-in/choices. The OS grant persists separately until revoked
in System Settings. Google/MCP samples remain synthetic and cannot use the real
provider. No external content transfer or telemetry exists. [ADR-0011](decisions/0011-calendar-authorization-discovery.md)
records discovery; [ADR-0012](decisions/0012-calendar-reads-availability.md) records reads.
Live TCC/sandbox/provider behavior remains unverified. Availability results contain
only bounded occupied/uncertain intervals and observation metadata, with no event or
resource identifiers. The adapter does not access unrequested detail properties;
EventKit may internally materialize full objects, so this is not an OS field-access guarantee.

Google authentication code is implemented with a disabled, unconfigured composition.
No Google browser/request, callback receiver or credential access occurs in this app.
The adapter's intended activated data flow is browser consent, bounded HTTPS token
exchange, private non-synchronized Keychain storage, and explicit local disconnect
versus remote project-grant revocation. No identity scopes or profile/email request
is added. Logs and UI carry sanitized states only. Live handling remains unverified;
[ADR-0013](decisions/0013-google-oauth-keychain.md) records activation gates.

Future integrations must default off and be independently enabled. Limit every
connection to selected resources, operations, and fields. Availability-only sharing
must omit titles, descriptions, attendees, locations, links, and notes. Occupied
time ranges are themselves sensitive. More detailed sharing requires explicit
opt-in; tightening privacy must remove previously mirrored details.

Google connection must not enable AI, Contacts, Reminders, or Notes. Each service
requires its own consent. Disclose what leaves the device and the recipient;
MacHandle-operated cloud collection is not a default. Explain that application-level
read-only restrictions are distinct from EventKit OS authorization.

Before adding persistence or diagnostics, document purpose, location, retention,
deletion, credential handling, and support-export redaction. Never add real content
to fixtures or bug reports. Future disconnect/revocation behavior must explain
what local/remote data remains and what requires explicit deletion approval.

## PR-03 representations

Contact and calendar detail fields default to not fetched; fetched-empty and
unauthorized remain distinct. Availability blocks have no event detail fields.
Connection configuration defaults disabled. The domain defaults alone do not enforce grants; work package 04 adds isolated
policy filtering, while provider/transport enforcement remains packages 07/18/24.
Internal coverage metadata also contains resource references and must not be exported
without policy. No Codable formats or automatic exports are introduced.

## Work package 04 projections

The policy engine filters requested selected resources and fields, removes internal
revision/linked-contact metadata, and preserves provider-unfetched/denied/empty states.
Availability projections exclude source identities and event details. Hidden fields
cannot be used as contact search predicates. Unresolved unified Contact data denies
until the provider can prove safe field provenance for selected records. Old responses
are denied after observed revocation or policy tightening. No provider data is fetched
or transmitted, and application/transport composition remains later work.

## PR-02 implications for future consent

Explain that Calendar/Reminders full access is broader than MacHandle's selected
read-only policy, and native macOS Contacts subsets/fields are application-enforced.
Unfetched contact fields must remain distinguishable from empty values. Provider
objects stay inside their adapter; return only authorized domain fields.
See [ADR-0004](decisions/0004-platform-and-apple-apis.md).

Do not equate a Google secondary calendar or an event's visibility field with
verified private sharing. Narrow scope cannot inspect ACLs; unsupported account
privacy cases must remain blocked until PR-09/16 resolves the verification flow.
Local disconnect stops this Mac's future access; already mirrored data or data
returned to an MCP client is not automatically recalled. Google grant revocation can
affect other installations for that user/project and can take time to propagate;
it is not a per-device pause or writer-transfer mechanism. PR-08/14/16 must disclose
that distinction. Cleanup requires a separate explicit choice.
See [ADR-0005](decisions/0005-google-desktop-boundary.md).

Future credentials remain local to their owning signed app/Keychain namespace;
Git handoff copies source and decisions only. Locked/unavailable Keychain state pauses
work. No blanket helper access or cross-Mac credential synchronization is assumed.
See [ADR-0007](decisions/0007-lifecycle-identity-and-distribution.md).

## Work package 09 destination boundary

The internal Google client derives authority from local creation/operation records,
not calendar names, caller IDs or remote text. Session leases fence disconnects;
mutations use observed ETags and uncertain inserts require explicit verification.
Pagination never emits partial results or authorizes reconciliation. No source content
is sent: account-specific calendar privacy and signed activation remain blocked.
In-memory ownership is not durable or a cross-device writer lock. See
[ADR-0014](decisions/0014-google-destination-client.md) for limits and revisit owners.

## Work package 10 storage boundary

The isolated SQLite library stores private identity/mapping/version/fingerprint and
operation metadata only; no tokens or event bodies. It is not opened by the app.
Owner-only permissions, explicit creation/resume, exact schema and binding checks,
transactional unknown outcomes and conservative restore prevent automatic reset/replay.
Local advisory locks do not establish cross-Mac authority, and plaintext metadata is
not encryption or tamper-proof evidence. See [ADR-0015](decisions/0015-sqlite-persistence.md)
for backup, recovery, integration and live acceptance gates.

## Work package 11 planner boundary

[ADR-0016](decisions/0016-pure-reconciliation-planner.md) defines pure comparison only.
Public evidence flags and proposals confer no provider authority. Trusted composition
must establish freshness, complete coverage, identity/ownership and mapping integrity;
the executor must recheck current policy, writer authority and mutation preconditions.
Every delete requires confirmation; bounded absence, missing state and unknown writes
never authorize cleanup. Availability omits source details; privacy reductions explicitly
clear previously mirrored fields, unless a conflict requires intervention. No planner
output is logged or persisted here, and no live source content is accessed.

## Work package 12 execution boundary

[ADR-0017](decisions/0017-synchronization-executor.md) introduces internal execution with
default-deny authorization. Every HTTP attempt and result/checkpoint commit calls the
trusted authorization contract; there is no live implementation or public activation.
Durable unknown state precedes dispatch, conditional versions protect updates/deletes,
and separate reads verify results. Lost responses never trigger new IDs or blind replay.
Tests use synthetic transport and temporary SQLite only. No source writes, real content,
account access, broader OAuth scope or runtime app activation is introduced.

## Work package 16 onboarding boundary

Availability remains the default; title/location/notes are explicit local choices. A
privacy reduction invalidates approval and pauses before a new reviewed clearing update.
Preview displays only permitted projection; generic labels do not restore hidden details.
Candidate source fingerprints and field bits reside in the identity-bound SQLite store;
no raw event content, enabled bit or approval persists. Disconnect preserves remote copies
and discloses incomplete credential/grant removal. See
[ADR-0021](decisions/0021-google-sync-onboarding.md). Live account/sharing/Keychain proof
is still required; the app opens no Google database or external connection at launch.

## Synthetic MCP transport — work package 17

The helper never accesses real resources, credentials or local stores. No incoming frame,
argument, client metadata, cancellation reason or raw exception is logged. Protocol errors
are fixed strings; stdout holds only bounded JSON responses. Tool results are synthetic.
No resource text is treated as instructions. The
[signed broker gate](decisions/0022-mcp-server-foundation.md#remaining-signedlive-gate)
and package 19 identity/revocation remain necessary before any personal-data exposure.

## MCP read projection — work package 18

Availability contains no event/calendar identifiers or content. Discovery filters selected
resources; search/detail use explicit fields without provider IDs, series or revisions.
Temporary handles retain only bounded reference/window metadata, not event content.
Queries/errors/content are not logged, and source text is never interpreted as instructions.
See [ADR-0023](decisions/0023-mcp-calendar-reads.md). All executable data remains synthetic;
signed broker/identity/current-OS integration is required before live activation.

## MCP connection metadata — work package 19

Saved candidate labels/resource references/grants are private metadata, stored only through
an explicitly selected private atomic file adapter. No credentials, enabled sessions or
approvals persist. The synthetic executable uses memory only. Audit retains at most 256
actions/connection UUIDs/operation kinds, without content, resource IDs, queries, labels or
raw errors; prepared reads are not delivery receipts. See
[ADR-0024](decisions/0024-mcp-connection-identity.md). Same-user file integrity does not
establish identity; local review is still required after restart or settings restoration.

## Action review data — work package 20

Local review retains only bounded selected fields after independent projection and current
review-read policy checks. Literal text/clearing semantics are distinct; content is never
interpreted as approval. Audit stores phase, operation/connection IDs and sequence only. Review,
confirmation and audit are memory-only and the app uses fixed synthetic fixtures. No snapshots,
arguments, screenshots or credentials persist. See [ADR-0025](decisions/0025-action-proposal-approval.md)
for the separate durable-intent/recovery requirement before live writes.

## Calendar mutation journal — work package 21

The separate installation-bound journal stores only random operation UUIDs and fixed outcome states;
no source identifiers, labels, arguments, content, provider errors or approval handles. Private-file
and single-writer protections reuse SyncPersistence. Pending/unknown survives restart and blocks
writes; no automatic reconstruction, replay or recovery-by-deletion exists. Production composition
still denies. [ADR-0026](decisions/0026-calendar-mutation-journal.md) records limits and ownership.

## Reminders read minimization — work package 22

Only requested Reminder properties leave the provider, and independent policy projection precedes MCP matching/output. Notes are opt-in for native details and denied by the synthetic MCP fixture. EventKit itself fetches full objects, so field projection is not a claim of native field-selective fetching. Local source account labels help list selection but are not exported by MCP. Due/completion/recurrence-presence remain separate; no alarm or occurrence schedule is inferred.
See [ADR-0027](decisions/0027-reminders-reads.md) for bounds, alternatives and owned acceptance.

## Contacts field minimization

[ADR-0029](decisions/0029-contacts-reads.md) limits native reads to selected containers/records and
explicit property keys. Names-only local search and optional detail choices avoid whole-contact
exports. Identifier-only membership scans do not fetch hidden names; unification and linked-ID
exports are disabled. No contact content is persisted or logged. Notes remain unavailable, and
synthetic MCP fixtures do not connect to a real Contacts store.
