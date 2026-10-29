# ADR-0030 — Approved Contacts management and durable containment

Date: 2026-10-29. Status: implemented for review in work package 25; production writers closed.
Requirements: [PR-25](../../product/master-spec.md#pr-25--authorized-contacts-management),
[§10](../../product/master-spec.md#10-contacts-integration) and
[§4](../../product/master-spec.md#4-security-and-permission-model).
Builds on [Contacts reads](0029-contacts-reads.md), [approval contracts](0025-action-proposal-approval.md)
and [Reminder containment](0028-reminders-management.md).

## Authority and exact review

Use independent typed create, selected-field update and delete proposals. Saved v3 candidates stay
read-only; there is no write-grant migration. Creation needs whole-container selection; an existing
record must be in the connection's exact subset. Google remains denied. A new scoped observation
request checks identity, OS, container/record, operation, changed readable/writable fields and local
review fields before observing an existing target. It allows an unknown revision only for observation,
never execution. The engine binds the trusted observation into a new proposal and independently
checks mutation policy. Caller versions, read handles, resource text and permits are not approval.

The independent ContactApprovalEngine strips provider over-return and requires exact underlying
record identity. Updates review name plus changed fields. Deletion requires all five supported field
groups to be readable, an acknowledgement of whole-record removal (including unshown photos/notes),
and typing `DELETE`. No bulk operation or automatic undo exists. Reviews are inert quoted text with
account/container, before/after values and scope; control/format characters and oversized content
are rejected. Two-minute reviews and thirty-second confirmations are single-use, instance/connection
bound, current-policy checked, and serialized at admission. Stale snapshots, missing/unified/foreign
records, unknown revisions and no-op changes are denied. A bounded metadata-only audit records fixed
phases and random operation/connection IDs, not field values or contact identifiers.

Names modify given/family components only. Email/phone/postal arrays are explicit whole-field
replacements, with labels shown in native reviews. Organization can be cleared. Notes are never read
or written. In-memory native mapping preserves unrelated properties. Existing postal addresses with
unmodeled subLocality, subAdministrativeArea or ISO country code are rejected before replacement,
rather than silently erasing those components. Other linked/name/group/photo metadata is not edited.

Native Connections offers three fixed synthetic review samples. MCP adds propose_contact_change
and commit_contact_change using a separate fixed fixture authority. Wire arguments can propose four
field groups (given/family name, email, phone, organization), with whole unlabeled array replacement;
partial names are rejected. Postal input waits for a structured address schema. A native-only method
can confirm an adapter review; neither acknowledgement nor typed phrase is exposed as wire authority.
The standalone helper has no approval bridge, so its proposals cannot execute. Read and mutation
fixtures have separate connections/IDs; read handles cannot cross into mutation authority.

## Durable dispatch and Contacts limits

ContactMutations has no public live constructor. A dedicated ContactMutationJournal shares only the
hardened SQLite primitive, with its own application ID, exact schema/installation binding and private
exclusive file contract. Calendar/Reminder stores are rejected. It stores only operation UUIDs and
pending/applied/notApplied/unknown states, writes intent before dispatch and validates/persists the
receipt before success. Pending/unknown blocks restart and all subsequent writes. A lost receipt or
mismatched operation yields unknown, never rollback or replay. The 4,096-record cap fails closed;
there is no reset, pruning or automatic retry path. No production database is opened.

The gated Contacts backend owns public CNContactStore/CNMutableContact/CNSaveRequest values inside
its actor, never prompts, and accepts only exact trusted candidate containers. CNContainer has no
used writability guarantee; neither its type nor caller input proves write access. Any future trusted
composition must establish writable candidates and shared session identity during isolated acceptance.
The live factory always denies; no environment/Boolean/build override activates it.

Observation uses fresh store fetches, unification off, identifier-only membership before and after
minimal-key fetching, and current authorization/change generation. An in-memory revision hashes the
scoped observed values, identity and store-change epoch; it is not persisted and is not an Apple
server revision. Apply repeats the expected snapshot comparison, patches only fetched properties,
builds one save request, revalidates authorization after preparation and checks OS/change epoch before
synchronous dispatch. Post-dispatch cancellation cannot imply rollback. Success means local API
acceptance only; errors after execute begins are conservatively unknown.

Apple explicitly documents overlapping/concurrent saves as **last change wins**. There is no expected
revision parameter in CNSaveRequest. Notifications can lag, unrequested properties can change, and
another process/cloud sync is not serialized by our actor. Hashes and mock atomicity cannot establish
external atomic conflict protection. Membership scans stop at 1,000 identifiers or a cooperative ten
seconds; they cannot interrupt a blocked API. These checks are stale-state detection and containment,
not a production safety guarantee. Signed/runtime acceptance and a reviewed conflict contract remain
required before enabling writes, especially deletion of linked records.

## Alternatives, consequences and retained gates

Rejected unified targets, whole-address-book snapshots, inferring writes from OS/read grants,
Calendar/Reminder journal reuse, trusting caller approval/version and retrying an ambiguous save.
Distinct service types duplicate some lifecycle code but make authority/journal boundaries explicit.
A pre-save comparison is useful even though it cannot turn Apple's last-writer-wins API into CAS.

| Capability / owner | Current limit and reason | Revisit trigger |
| --- | --- | --- |
| Production writer, actual clients and native pairing — engineering/maintainer | Closed factory; no approved signing/peer/current-OS bridge or accepted provider conflict guarantees | Signed identity/setup, trusted writable container/session binding and explicitly authorized isolated account acceptance before live activation |
| Linked-record deletion, cross-account moves and minimum OS/home Mac — engineering/maintainer | No runtime effects proven; unified targets/merge/move operations unsupported | Isolated linked-record fixtures establish exact unchanged-record effects and conflict handling on supported hardware/OS |
| Postal replacement with unmodeled components — engineering | Denied rather than erasing additional components; core/synthetic five-field contracts remain implemented | Expand typed fidelity/review and native round-trip evidence before permitting those records |
| Postal wire arguments — engineering | Deferred wire mapping; current scalar/string-array protocol schema cannot represent labeled structured addresses clearly | Reviewed structured input schema and exact-field parsing/privacy tests before exposing postal changes to clients |
| Contacts notes — engineering | Restricted entitlement and consent gate from ADR-0029; no access | Entitlement eligibility/approval plus explicit privacy review and isolated evidence |
| Unknown recovery and journal retention — engineering | Durable containment only; finite cap; absence/equality is not execution proof | Reviewed recovery/retention plan preserving uncertainty and replay tombstones before live activation |

These limits retain requirements; they do not authorize future packages. Package 26 is a planned
Notes.app feasibility brief only. No Notes feasibility verdict or release is claimed.

## Evidence and primary sources

[Acceptance](../../implementation/prs/pr-25.md#implementation-and-acceptance) and
[developer checks](../../development/contacts-management.md) map synthetic tests, native value/API
compilation, presentation and protocol evidence. Full staged/final results belong in progress and the
PR. Tests never execute CNContactStore saves or read personal contacts.

Official Apple sources checked 2026-10-29:

- [CNSaveRequest](https://developer.apple.com/documentation/contacts/cnsaverequest): one request per operation, last-change-wins overlap, missing/existing record errors and no object access during execution.
- [CNMutableContact](https://developer.apple.com/documentation/contacts/cnmutablecontact): modify only fetched properties; mutable values are not thread-safe; empty arrays/strings clear values.
- [Contacts framework](https://developer.apple.com/documentation/contacts): mutable-copy updates, execute and change notifications/refetch.
- [Delete contact](https://developer.apple.com/documentation/contacts/cnsaverequest/delete(_:)-8m1tc) and [shouldRefetchContacts](https://developer.apple.com/documentation/contacts/cnsaverequest/shouldrefetchcontacts): public save surface, not a conditional-write contract.
