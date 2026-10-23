# Security model

## Current boundary

PR-01 has no provider access, integrations, account data, authentication, persistence,
or approval engine. Its minimal window cannot connect to any service. Build checks,
App Sandbox configuration, and repository scanners are foundations, not a security
audit or proof that future integrations are safe.

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
