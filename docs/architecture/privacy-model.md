# Privacy model

Current implementation: a development window, static presentation metadata, and
PR-03 domain values/tests for review.
No Apple permissions are requested, no integrations exist, no content is read or
sent, and no telemetry is implemented. This describes this code, not future releases.

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
Connection configuration defaults disabled. These structural defaults do not filter
provider output or enforce per-connection grants yet; PR-04/07/18/24 own that behavior.
Internal coverage metadata also contains resource references and must not be exported
without policy. No Codable formats or automatic exports are introduced.

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
