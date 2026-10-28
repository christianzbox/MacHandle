# Security model

## Current boundary

The native interface has opt-in Calendar discovery and selected bounded local reads.
It has no event writes, active external integrations, content persistence or approval issuer.
OAuth/Keychain code exists but its live service remains unconfigured. Synthetic connection
controls cannot connect a service. Live TCC/sandbox enforcement is unverified. Build checks,
App Sandbox configuration, and repository scanners are foundations, not a security
audit or proof that future integrations are safe.

## PR-03 model boundary

CoreDomain values are constructible data, never authorization capabilities. Disabled
connection defaults, distinct OS observations, resource-specific operations, exact
patches and explicit unknown outcomes support later enforcement. Read/write interfaces
are separate; this historical model package contains no policy or provider execution. Unified
contact references cannot be used directly as underlying-record mutation targets.
See [ADR-0008](decisions/0008-core-domain-contracts.md). Compile-time boundaries
reduce accidental coupling but do not isolate malicious code in the same process.

## Work package 04 policy enforcement

PermissionEngine implements default-deny resource/operation/field decisions and
response filtering in isolation. Only the trusted owner configures PolicyAuthority
and binds an independently identified connection. Clients receive PolicySession;
no public permit/session construction or caller-selected identity is accepted there.
Actual caller authentication remains a later integration requirement.

All decisions/projections use current actor state; policy replacement, revoke,
remove/recreate and OS observation changes invalidate old sessions/receipts. Exact
requests cannot borrow another session's receipt. OS permissions remain independent
per service. Source sync cannot gain Apple calendar writes, Reminders or Contacts.
Mutations inspect every changed field and require future local approval; unknown
preconditions deny. No runtime provider or single-use approval issuer exists.

[ADR-0009](decisions/0009-permission-policy-engine.md) specifies rechecks after
suspension and before dispatch/return, plus the remaining provider race/atomicity
limits. These are tested in-process rules, not live MCP/security-audit claims.

## Work package 05 application boundary

[ADR-0010](decisions/0010-native-application-foundation.md) adds explicit synthetic
composition. Views receive observable state/preview actions, not a PolicyAuthority.
Simulated OS observations belong to isolated preview actors and must never feed live
providers. Old results disappear during changes, fresh sessions revalidate receipts,
and no preview can grant a write. Labels distinguish a policy simulation from actual
authentication, permission, approval or execution. No sensitive material is persisted.

## Work package 06 Calendar boundary

[ADR-0011](decisions/0011-calendar-authorization-discovery.md) isolates EventKit behind
CalendarDiscovering. Only local Enable may prompt. Authorization is reread before and
after metadata discovery, and late results cannot undo disable/revocation or cancellation.
Selection never enables a connection or authorizes a read/write operation. Real metadata
never enters synthetic policy actors, history or logs. The Calendar entitlement grants
OS capability, not per-connection authority; future operations require policy checks.

## Work package 07 read boundary

[ADR-0012](decisions/0012-calendar-reads-availability.md) adds a private trusted local
read workflow, separate from preview authorities. Current OS observations, exact
selection and field/operation grants govern each read; receipts are revalidated after
provider suspension and filtered results receive a final OS check before publication.
Selection/permission refresh, disable, cancellation or form changes invalidate pending
results. No nil-calendar predicate, caller-selected authority or source write exists.
Local complete coverage does not prove remote freshness or authorize deletion.

## Work package 08 authentication boundary

[ADR-0013](decisions/0013-google-oauth-keychain.md) adds fixed-endpoint browser PKCE,
exact state/redirect/Host validation, a bounded one-attempt loopback receiver, ephemeral
HTTPS without redirects, scope validation and private client-bound credentials. Actor
generations reject stale sign-in/refresh results after disconnect. Local deletion and
project-wide Google revocation are separate choices; remote failure never restores
local access. No token-returning UI API, raw provider diagnostics or client-selected
endpoint is exposed. CoreDomain and PermissionEngine remain independent of auth.

Live activation is blocked on missing maintainer identity/console setup and signed
verification. No new network entitlement or Keychain item exists in the shipped app.
The code/tests do not establish live OAuth security, Keychain continuity or distribution.

## Required future controls

Protect personal content, credentials, resource identity, and approved mutations
against malicious clients, prompt-injected resource text, confused-deputy calls,
revoked connections, stale state, crashes, and compromised dependencies.

macOS authorization, per-connection policy, and local action approval are separate
trust boundaries. EventKit full access permits OS-level reads and writes; an
app-level read-only policy must be enforced by trusted code and disclosed as such.
Never trust a client-supplied name or an AI assertion of approval. Bind short-lived,
single-use approvals to exact identity, resource, operation, parameters, and version.
Check revocation at execution. Separate source-read and source-write interfaces.

Keep Google synchronization independent, one-way, and restricted to an app-owned
private destination. Incomplete source enumeration, revoked permissions, missing
accounts, corrupt mappings, and transient failures must not trigger deletions.
Use Keychain for credentials; redact diagnostics and never log personal content.
No unprotected remote endpoint, private Apple framework, or internal Notes database.

## Repository controls

Existing main ruleset enforces PRs, linear history, no force pushes/deletions,
conversation resolution, zero required approvals, and no bypass actors. Human
review is a workflow requirement even when GitHub allows zero approvals. GitHub
secret scanning and push protection were verified enabled on 2026-10-23.

PR workflows have read-only contents permission, no stored checkout credentials,
no secrets, and immutable action references. Gitleaks is version/hash pinned;
privacy checks inspect the index, including force-added prohibited files. These
are heuristics; a `_synthetic` label does not prove content is synthetic.
Manual diff review remains required. Review scanner/config changes carefully.

After the initial CI run passed, main was configured to require `Build and test`
and `Secret scan` from GitHub Actions, with strict up-to-date checks. All prior
rules were preserved. Do not weaken any existing rule. Independent review is required before a public
write-enabled MCP release; synthetic-account privacy tests precede distribution.

## PR-02 researched boundaries

[ADR-0004](decisions/0004-platform-and-apple-apis.md) distinguishes EventKit full
access and Contacts application subsets from OS-enforced read-only or field grants.
Snapshot coverage and provider identity are evidence, not universal freshness or
atomic mutation guarantees. Missing/ambiguous state must stop destructive operations.

[ADR-0005](decisions/0005-google-desktop-boundary.md) confines OAuth callbacks to a
short-lived loopback receiver with PKCE/state validation. The narrow scope supports
event CRUD but not CalendarList/ACL enumeration; private destination activation and
lost-identity recovery remain explicit gates. Remote Google grant revocation is
broader than a local connection disable; its effect may be delayed. Conditional
Google updates/deletes require observed ETags and conflict handling, while uncertain
inserts need durable operation identity and remote verification. No listener exists
in this PR.

[ADR-0006](decisions/0006-local-mcp-and-processes.md) separates shipped IPC peer
verification from local connection pairing: our signed helper is not proof of the
client driving stdin. Recheck policy generation before dispatch/return, invalidate
approvals on revocation, and distinguish queued cancellation from an already accepted
provider mutation. Protocol metadata and resource text never confer authority.

[ADR-0007](decisions/0007-lifecycle-identity-and-distribution.md) requires signed
Keychain/upgrade tests before credential continuity claims. App Sandbox, hardened
runtime and notarization address different threats; none proves per-connection
policy or protection against a compromised already-authorized client.

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

## Work package 16 local sync administration

The public presentation interface is trusted local UI administration, never an MCP tool.
Internal orchestration binds retained five-minute single-use reviews to exact plans,
selection, fields and canonical store. It composes rather than replaces existing account,
source, privacy, writer and full destructive-plan checks. Cancellation drains owned work;
late UI results cannot resurrect reviews. Ongoing consent cannot approve future deletions.
[ADR-0021](decisions/0021-google-sync-onboarding.md) records trust/activation boundaries.

## MCP foundation boundary — work package 17

The standalone helper exposes four fixed mocks only. Protocol metadata, initialization,
client names and request IDs never authorize application services. Internal registration
and module dependency guards prevent a public provider factory. Bounded framing/JSON,
concurrency, cancellation and output deadlines protect the synthetic transport; they do
not authenticate the controlling client or establish sandbox/TCC ownership. See
[ADR-0022](decisions/0022-mcp-server-foundation.md) before adding read adapters or IPC.

## MCP read enforcement — work package 18

Provider operations require current OS access and bound policy receipts; suspended results
are projected and revalidated before delivery. Search only examines permitted titles.
Opaque handles cannot confer authority or select another connection, and detail reads
refetch scoped data. No source-writing or administrative service reaches the transport.
See [ADR-0023](decisions/0023-mcp-calendar-reads.md). All executable data remains synthetic;
signed broker/identity/current-OS integration is required before live activation.

## MCP connection enforcement — work package 19

[ADR-0024](decisions/0024-mcp-connection-identity.md) adds a default-deny verified-channel
contract and locally issued, single-use, revision-bound reviews. No client label, metadata or
supplied UUID chooses authority. Saved settings restore no active lease; approval requires
fresh OS observation and peer checks. Disable/revoke/policy/OS/shutdown close admission,
cancel reads and invalidate prepared output. Uncooperative cancelled providers retain shared
capacity. Failed persistence closes the whole controller. Real signed mutual verification,
local review UI and current OS/transport wiring remain explicitly unimplemented activation gates.

## Action approvals — work package 20

Exact typed proposals bind to the existing session identity/generations and local non-Codable
review/confirmation handles. Caller arguments cannot replace a stored mutation at commit.
Consumption and serialized admission precede awaits; current policy/channel/OS/expiry and
provider state are checked before dispatch, with conditional comparison in the mock provider.
Unknown receipts block further actions and never trigger automatic retry. Accepted writes may
finish after cancellation/revocation. See [ADR-0025](decisions/0025-action-proposal-approval.md).
No live writer, writable MCP grant, caller approval endpoint or durable recovery claim is added.
