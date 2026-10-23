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

Require observed CI check names in the main ruleset once jobs have actually run.
Do not weaken any existing rule. Independent review is required before a public
write-enabled MCP release; synthetic-account privacy tests precede distribution.
