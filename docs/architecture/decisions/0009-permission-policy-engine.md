# ADR-0009: Trusted policy authority and revocable connection sessions

Date: 2026-10-26 (America/Detroit). Status: work package 04 merged in GitHub PR #5
at `0cdac4bd5845b2b167a48c00332ef5ddf5080606`. Requirements: specification §§4, 6, 20 and legacy PR-04.
Prerequisite: work package 03 merged in GitHub PR #4 at
`a990e05721e75770df98ba01c2bad2bc5aa731a7`, verified before branching.

## Decision and trust boundary

Add one PermissionEngine target depending only on CoreDomain. Foundation supplies
opaque in-memory generation/session identifiers; no provider, UI, storage or transport
imports/dependencies. Pure PolicyRules evaluate immutable configuration and requests.
A PolicyAuthority actor serializes configuration, binding, decisions and filtering.
There is no global singleton, clock-based decision, real permission request or I/O.

Only trusted application/broker code owns PolicyAuthority. It installs Connection
and ConnectionPolicy values, supplies current OS observations, and binds an independently
identified caller with bindTrustedConnection. This method is an explicit trusted
composition boundary, not an authentication implementation. The returned PolicySession
has no public initializer, configuration methods, identity selector or authority handle.
A transport must receive only that session. Pairing/channel authentication remains
work package 19; callers must never choose the ID supplied to the binding method.

PolicyPermit is a nonconstructible, immutable receipt bound to one authority, session,
connection generation, OS generation and exact typed request. It has no Codable
representation and is not a cryptographic token or write approval. All mutation
receipts report requiresLocalApproval; no execution API exists in this package.
Resource text and caller approval claims cannot set any trusted state.

## Policy and projection contracts

| Boundary | Enforcement |
| --- | --- |
| Defaults | Connections retain CoreDomain's disabled default. Empty ConnectionPolicy/ResourceGrant selects/grants nothing. Unknown, disabled and revoked connections deny; missing OS observations deny. No automatic AI or Google grant. |
| Selection | Calendar/list/container keys match the full provider/store/account/local identity. Empty request selections never mean all. Contact records are selected explicitly or through deliberate whole-container consent. |
| Operations | Each resource-specific operation is independent. Create does not grant delete; reminder update does not grant completion/due changes. Read requests cannot use mutation operation enums. |
| Fields | Requested/read and changed/write fields are checked separately. Each changed field, including an explicit clear, requires both visible and writable grants. Create checks every supplied field. Delete additionally requires detail/name/time preview permissions, as applicable. Deletion is a separate whole-record operation, not a field patch. |
| OS access | Calendar, Reminders and Contacts observations are independent. Current policy requires fullAccess, including for mutations. Unknown/unsupported/write-only/restricted/denied states fail closed. Narrow write-only create workflows may be reconsidered by the calendar provider package with runtime evidence; they are not promised now. |
| Source sync | googleSync can receive selected calendar read operations, but cannot receive source-calendar mutations, Reminders or Contacts access even if misconfigured grants list them. Google destination writes belong to a separate future destination client; this module governs Apple source-resource policy. |
| Preconditions | Existing-item mutations require an observed revision; unknown recurrence anchors deny. An opaque revision is only evidence to carry forward. Current provider comparison/atomicity and uncertain-write recovery remain later operation/provider gates; an allow is never execution permission by itself. |
| Calendar projection | Details/summary require explicit permission for structural time/occupancy/status fields. Summary cannot request location/notes. Allowed-but-unrequested details become notFetched; unauthorized details become notAuthorized. Provider series/revision metadata is stripped. Exact calendar/window coverage must match the receipt. Internal typed resource references still require transport shaping later. |
| Availability | Only time/occupancy fields and checkAvailability qualify. A details filter rejects an availability receipt. PermittedAvailability contains window/blocks/observation, with no source IDs, titles, locations or notes. Partial/unknown observation state is retained; no inference of free time or safe deletion. |
| Reminders/Contacts | Filter selected lists/records, project only requested permitted fields, retain fetched-empty/provider-unfetched/provider-denied distinctions, remove revisions and linked Contact record inventories. Discovery also filters requested selected resources; enumeration state remains intact. |
| Contact search | Both returned fields and explicitly named search fields need visibility grants. Providers must honor that search-field set and selected-record scope rather than searching hidden values and merely hiding them afterward. No actual search/provider exists yet. |
| Unified Contacts | Deny unresolved unified responses even when linked IDs are present; current metadata cannot prove field provenance/freshness within a selected subset. Underlying selected records are supported. New Contact creation requires whole-container consent because the new ID is not in a preselected record set. |

## Revocation and operation sequencing

Every policy replacement produces a new connection generation. Removal/recreation
cannot revive previous sessions. Revocation marks the connection revoked and advances
its generation. A changed OS observation advances an authority-wide OS generation;
unchanged observations do not. Old receipts/sessions then deny, including after
re-enabling or regranting. Obtain a newly bound session under current trusted context.
Denial precedence is fixed across resource sets, independent of Set iteration order.

All evaluations and response filters read current actor state. Filtering does not
suspend between validation and projection. Future trusted operations must:

1. Establish identity outside request arguments, bind a session, and evaluate the exact request.
2. Use only the permitted source selection/fields for the provider call.
3. Revalidate after any suspension and immediately before dispatch or response delivery;
   filter returned data with the same receipt, exact request and current policy.
4. For writes, obtain the separate trusted local approval and current provider
   preconditions, then execute exactly the receipt's immutable proposed change.

The actor orders its own checks, not remote provider transactions. Revocation cannot
recall data already returned or undo a write already accepted by a provider. The
check-to-provider race and cancellation handling remain work packages 19–25. No
claim of live revocation, single-use approvals or transport security follows here.

## Alternatives, constraints and consequences

- A caller-selected ConnectionID or public authenticated/approved Boolean would
  allow identity substitution. Instead the trusted owner creates a narrow session;
  compiler checks reject client access to its administration handle and permit
  construction. This guards composition mistakes, not malicious same-process code
  that already holds the full authority or can instantiate a new one.
- A stateless evaluator alone cannot invalidate an old decision after configuration
  changes. Keep rules pure but use one actor as the current authority; no copied
  policy snapshot is accepted as a live grant. A read-only decision cache was rejected.
- Global mutable state/locks and a general callback executor would add hidden
  dependencies or prematurely implement operations. The actor exposes data decisions
  and projections only. It stores no raw provider results and invokes no client code.
- Numeric counters could wrap or collide after removal/recreation. Opaque generations
  avoid reuse in this in-memory implementation. They are not persisted identities or
  a distributed protocol; persistence/restart semantics belong to later packages.
- Treating an allow receipt as write approval would collapse security layers. All
  writes conservatively require future local approval. Configurable approval UX and
  single-use tokens are work package 20, rather than an untrusted bypass flag now.
- Partial unified Contact filtering could leak fields merged from an unselected
  record. Work packages 24/25 own revisiting unified support after field provenance,
  linked-record freshness and container-scope tests. This explicit limitation does
  not remove the product's Contacts/unified-identity requirements.

## Evidence and limits

Public-API synthetic tests cover defaults, OS isolation, namespace and connection
isolation, every changed Calendar/Contact field, explicit clearing, operation
escalation, source sync writes, hidden search fields, projections, revocation,
remove/recreate, foreign receipts and policy reduction while a response is pending.
The existing validator also checks the module dependency/import boundary and rejects
client administration, authority access, permit construction and availability detail
access in compile-fail probes. See the [work package 04 acceptance map](../../implementation/prs/pr-04.md#implementation-and-acceptance).

No providers, app integration, actual OS observation, live authentication, trusted
approval issuance, storage, network, UI feature, signed sandbox or home-Mac behavior
is implemented or verified. Exact local/hosted evidence is recorded in the GitHub PR
and [progress](../../implementation/progress.md), separately from these design limits.

## Work package 17 follow-up

[ADR-0022](0022-mcp-server-foundation.md) implements an isolated synthetic stdio helper,
explicit modern/legacy protocol handling and a bounded mock registry. It establishes no
caller identity, IPC trust or provider authority. Signed packaged broker proof remains
owned by engineering/maintainer after approved identity setup; it is not waived by SDK
interoperability. Package 18 adapters remain externally disabled until that proof and
package 19 identity/revocation gates pass.

## Work package 18 follow-up

A separate read adapter receives a bound PolicySession, never a configurable authority.
It projects before matching and supplies a delivery revalidation closure. The executable
composes only a fixed synthetic authority; identity and real channel binding remain package 19.
[ADR-0023](0023-mcp-calendar-reads.md) records bounds, alternatives and acceptance.
Signed broker and personal-data activation gates remain open.
