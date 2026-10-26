# Security model

## Current boundary

The native interface has opt-in Calendar metadata discovery, but no event reads or
writes, external integrations, persistence or approval issuer. Synthetic connection
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
