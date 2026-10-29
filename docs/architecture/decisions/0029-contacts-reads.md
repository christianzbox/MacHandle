# ADR-0029 — Independent, field-minimized Contacts reads

Date: 2026-10-29. Status: implemented for review in work package 24; signed/runtime
acceptance and live MCP activation remain open. Extends [ADR-0004](0004-platform-and-apple-apis.md)
and [ADR-0009](0009-permission-policy-engine.md).

## Decision and alternatives

Use public Contacts.framework behind an isolated `AppleContactsProvider` actor and immutable
CoreDomain contracts. Permission is requested only from the native Enable action; discovery,
refresh and reads never request it. A lazy CNContactStore prevents initialization on app launch.
Calendar, Reminders and Google permissions cannot grant Contacts access. The app adds the public
address-book sandbox entitlement and NSContactsUsageDescription; no Contacts notes entitlement.

Enumerate underlying records with `unifyResults = false`. Identifier-only enumeration verifies
selected-container membership before fetching selected records with exactly the requested property
keys, then checks membership, selected inventory, change generation and authorization again.
Explicit record subsets (up to 256 IDs per selected container) are application policy, not an OS
limited-contact grant. Ambiguous duplicate identities, unified results, foreign results, disappearing
membership and incomplete field fetches fail closed. Native UI selects containers; record subsets
are implemented in trusted connection settings/contracts, with the live pairing UI still gated.

We rejected default unified results: their aggregate fields may originate in an unselected linked
record. This package deliberately shows underlying records separately; it does not guess provenance,
export linked IDs or promise deduplication. We rejected native name predicates and formatter key
descriptors because they could match/fetch fields outside the request. Projection precedes in-memory
matching against explicit permitted search fields; postal fields are detail-only. The native UI
searches names only and requires optional field choices for details. Notes are unsupported, not
silently fetched. Google connections are denied Contacts reads.

CNContact identifiers are device-local. Container identifiers are not account identities. This
provider uses a random store identity per instance, scoped container IDs and raw record IDs; saved
candidates cannot silently regain authority across launches. Fresh discovery/review is required.
This trades convenience for safe identity continuity until a supported persistent binding is proven.
No keychain, contact database, content cache or export is added.

## Bounds, uncertainty and transport

Requests select at most 32 containers, with at most 1,000 identifier candidates across them.
Field fetches include only the selected subset; bounded post-fetch membership checks may scan
1,000 identifiers per returned container. A large first container may exhaust the candidate budget;
that is partial coverage, not absence. Scalar values are bounded to 4 KiB, each record to 16 KiB and
labeled arrays to 32 items. A ten-second cooperative deadline and cancellation are checked between
and within enumerations; they cannot forcibly interrupt a blocked Contacts API call. Notifications
and rechecks reduce races but are not an atomic snapshot or a remote freshness guarantee.
Missing detail is unknown; no result authorizes deletion.

MCPContactsAdapter depends only on transport, domain, policy and connection contracts. Three read
tools use paired independent grants, temporary opaque container/record handles, five-minute record
expiry, at most 512 handles, 100 results and a 16 KiB response. Current lease/OS/permit authority is
revalidated before queued transmission. Caller IDs and resource text confer no authority. Only the
fixed synthetic fixture configures policy; the stdio helper has no live provider dependency.
Saved settings v3 adds independent Contacts candidates; v1/v2 migrate without Contacts grants,
and older envelopes carrying Contacts candidates are rejected. There are no saved writable fields.

## Evidence and remaining gates

[Developer checks](../../development/contacts-reads.md) and
[package acceptance](../../implementation/prs/pr-24.md#implementation-and-acceptance) record
synthetic provider, model, policy, adapter, compiler and protocol evidence. In-memory CNMutableContact
normalization tests never instantiate a store or access personal contacts.

Engineering owns the following open work; none is implied complete by compilation:

- Signed native TCC/sandbox, account/container moves and linked-record behavior on an explicitly
  authorized isolated fixture account, minimum macOS and home Mac. Revisit after signing/setup and
  explicit fixture permission; no personal contacts are test data.
- Signed peer authentication, native pairing/record selection and current-OS integration before
  enabling any real external Contacts access. Saved candidates and synthetic peer checks are not
  production identity proof.
- Contacts notes: defer because macOS 13+ requires Apple's restricted notes entitlement and a separate
  consent/privacy design. Engineering revisits only after entitlement eligibility and approval are
  established, with explicit field review and isolated tests; no promise that Apple will approve it.
- Unified display/deduplication and persistent store continuity: engineering must demonstrate safe
  provenance and account/store changes before adding either. Underlying-record reads remain supported.
- Contacts writes belong to separately authorized work package 25. Reads expose no writable revision
  or mutation authority. Notes.app feasibility remains work package 26.

## Primary sources checked 2026-10-29

- [CNContactFetchRequest.unifyResults](https://developer.apple.com/documentation/contacts/cncontactfetchrequest/unifyresults): default unified values versus underlying records.
- [keysToFetch](https://developer.apple.com/documentation/contacts/cncontactfetchrequest/keystofetch): explicit requested properties.
- [Accessing the contact store](https://developer.apple.com/documentation/contacts/accessing-the-contact-store): authorization and restricted notes entitlement.
- [CNContact.identifier](https://developer.apple.com/documentation/contacts/cncontact/identifier): device-local identity.
- [Contacts framework](https://developer.apple.com/documentation/contacts): supported predicates and background fetching.
- [Contacts sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.addressbook) and [usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nscontactsusagedescription).

Pinned macOS SDK compilation verifies the native authorization cases used here; iOS limited-access
semantics are not assumed to exist on macOS. Official API documentation does not prove runtime
behavior for the signed app or constitute App Store approval.
