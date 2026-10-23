# Privacy model

Current implementation: a development window and static presentation metadata.
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
