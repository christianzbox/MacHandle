# ADR-0024: Channel-bound local MCP approval and revocation

Date: 2026-10-28. Status: merged in GitHub PR #20; synthetic peers only.
Requirements: [PR-19](../../product/master-spec.md#pr-19--mcp-connection-authentication-and-revocation),
[security model](../../product/master-spec.md#4-security-and-permission-model),
[ADR-0006](0006-local-mcp-and-processes.md) and [ADR-0009](0009-permission-policy-engine.md).

## Decision and authority

MCPConnections owns trusted connection administration, separate from the dependency-free
protocol and the read adapter. Only the fixed synthetic composition currently uses it.
A trusted channel adapter supplies peer verification and closure. Verification defaults to
false; no production XPC verifier is implemented. A synthetic true result is fixture code,
never an assertion supplied through MCP arguments, metadata, connection labels or IDs.

Trusted local administration creates a disabled candidate with explicit Calendar references,
read operations and visible fields. Pairing checks the exact channel, then produces a
controller-issued pending handle. Local review selects a candidate and captures its revision,
channel, issuer, nonce and monotonic expiration (60 seconds from request). Approval consumes
the review once, rechecks the peer and current OS observation, and binds a narrow PolicySession
and selection to that launch. Each actor suspension checks the current generation, record
revision and gate. One configuration has at most one active launch; replacing it closes the
old launch. Different configurations remain independent. Restart requires fresh peer checks,
OS observation and local approval. No token, enabled session or approval is restored.

Labels are display values, not proof of third-party application identity. Identically named
records gain nothing from each other. The helper cannot choose a saved identity, approve,
configure permissions or revoke another connection. Reviews and administration are package
internal and absent from wire schemas; compiler probes enforce the external module boundary.
Pairing alone supplies no resource, field or mutation grant. Sync remains independent.

## Invalidation and limits

Disable, revoke, policy edits, shutdown and observed OS changes synchronously close admission
and cancel owned reads before persistence or actor suspension. Revocation stays revoked in
saved settings; disable permits only a subsequent fresh local pairing. Disconnect closes only
its own launch, so a delayed old disconnect cannot revoke a replacement. Duplicate channels
are closed and their running work cancelled. Revalidation also runs immediately before the
transport delivers prepared results; data already delivered cannot be recalled.

Limits are 32 saved candidates, 32 grants per candidate, 8 pending requests, 16 total active
and pending channels, 4 reads per channel and 16 reads across the controller. Cancellation
retains read slots until even an uncooperative provider returns, preventing repeated launch
replacement from bypassing the shared bound. Expired pending requests are pruned on subsequent
pairing/review/approval activity; idle expiry is not a wall-clock timer. Existing protocol
concurrency/output bounds and Calendar projection/handle limits remain in force. Future live
provider composition still needs bounded deadlines and transport EOF/shutdown wiring.

The bounded in-memory audit retains 256 monotonically ordered records: action, optional
connection UUID and operation kind only. It contains no labels, resource IDs, queries, event
content, credentials, client metadata or exception strings. `readPrepared` means a result was
prepared, not that the caller received it; late delivery can still fail revalidation.

## Permission persistence and alternatives

Save only versioned candidate configuration: UUID/revision, local label, selected Calendar
references, read/field grants and revocation. These are private metadata even though they are
not credentials. The explicit file store uses a private canonical directory, owner/mode and
inode checks, no-follow opens, a single writer lock, bounded validation, temporary 0600 file,
fsync and atomic rename. Missing/corrupt/future/oversized or unsafe existing state fails closed;
creation is a separate explicit operation. A failed save closes all admission and latches the
controller unavailable, even if the file replacement may have completed. A fresh controller
still restores candidates only. No default path, app-container selection or live store is
composed by this package. Memory storage is explicit for fixtures.

The specification lists SQLite as the **preferred** local persistence technology. Sync keeps
its existing SQLite store and schema. For this bounded, whole-document candidate list we
choose atomic JSON rather than coupling independent MCP configuration to the sync database
or introducing a second SQL schema/engine. There are no relational operations or durable
execution receipts here. The tradeoff is whole-file replacement and no migration beyond
explicit version rejection. Revisit with engineering before adding mutation receipts,
searchable audit history or credential-backed unattended pairing; those may warrant separate
SQLite persistence. UserDefaults was rejected because it cannot provide the explicit private
file, exclusive writer and failure semantics used here. In-memory-only settings lose the
requested configuration persistence. None of these files authenticate a peer or protect
against a compromised same-user process rewriting its own candidate settings.

## Protocol and credentials

The current [MCP authorization profile](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)
was checked on 2026-10-28: it targets HTTP and treats stdio credentials separately.
ADR-0006 intentionally imposes stricter local requirements than passing reusable environment
credentials: per-launch local approval with authenticated shipped peers. No bearer credential,
OAuth scope, environment token or helper-wide Keychain secret is added. Future secrets belong
in Keychain after reviewed provisioning and client/channel isolation. Modern per-request
metadata and legacy initialization remain protocol handling, not authentication.

## Verification and open activation gate

Eighteen new Swift tests cover single-use/foreign/expired/stale reviews, default-deny and
changed peers, revoke during approval/read, independent and empty grants, late output,
OS changes, shutdown/restart, duplicate channels, retained cancellation capacity, bounded
audit, unsafe files and failed persistence. Existing stdio and official SDK checks now run
the synthetic Calendar tools through this controller. See [developer checks](../../development/mcp-connections.md)
and [acceptance ledger](../../implementation/prs/pr-19.md#implementation-and-acceptance).

**Live authentication and native pairing UI are not implemented or verified.** Engineering
and the maintainer own the retained gate: once an approved development identity is supplied,
build the signed external-helper → broker harness, install mutual signing requirements tied
to the expected authority and identifier on the exact channel, prove sandbox reachability,
connect local review UI/current OS observation/EOF/shutdown, then exercise rejection, restart,
permission changes, minimum/current OS and actual desktop clients using synthetic resources.
No team/identity, actual signed peer evidence or live source access is invented. Personal
Calendar exposure stays disabled until all those checks pass. Work package 20 can build mock
proposal contracts independently, but cannot waive this gate or activate real writes.

## Work package 20 follow-up

[ADR-0025](0025-action-proposal-approval.md) adds separate trusted Calendar action reviews,
expiring single-use confirmation, provider-state checks and serialized mock dispatch. The
session exposes its existing bound identity to trusted package composition, never an identity
selector. Saved MCP grants remain read-only; no transport approval API or live writer is added.
Native sample review is independent of live pairing. Signed/runtime gates remain open, and
package 21 must add durable intent/recovery before any real source writes.
