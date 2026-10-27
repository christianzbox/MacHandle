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
