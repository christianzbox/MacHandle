# ADR-0006: Local MCP and process trust boundaries

Date: 2026-10-23 (America/Detroit). Status: accepted design direction for PR-02
review; external-helper IPC and client interoperability remain gated experiments.
Requirements: master specification §§4, 6, 8 and 13.4–13.5.

## Decision

Keep local MCP on stdio in a separate, minimal Swift executable. Keep provider
objects, policy, approvals and credentials in a trusted app-side broker. Google sync
uses the same authorized application services independently of MCP. The executable
parses bounded requests and forwards typed operations; it must not own EventKit,
Contacts access, Google refresh tokens or an alternate policy implementation.
No production helper, broker, transport or listener is introduced in PR-02.

Retain App Sandbox and hardened runtime. Prefer explicit XPC privilege separation
between shipped components, with no root daemon. Apple's
[sandbox guidance](https://developer.apple.com/documentation/security/discovering-and-diagnosing-app-sandbox-violations)
distinguishes inherited child-process permissions from separately configured XPC
services/login items. Its [embedded-tool guide](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app)
describes a tool launched by its containing app. That is **not evidence** that a
third-party MCP client can launch the same helper and inherit the app's sandbox,
TCC grant, container access or private XPC endpoint.

Therefore PR-17 must first prove the packaging/IPC path in a signed synthetic harness:
external launch → minimal helper → authenticated app-side broker, including absence
of the app, restart and sandbox denial. Evaluate a user-session registered service
if embedded-service discovery is insufficient. Do not silently add global Mach lookup
exceptions, app groups, broad file access, a network broker or disable sandboxing.
If supported scoped IPC cannot be demonstrated, stop live activation and record an
explicit design revision/deferral; mocks can still test protocol/policy contracts.

## Protocol evidence and version gate

All linked official sources were checked on 2026-10-23. The
[current transport index](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports)
resolved to revision **2026-07-28**, with stdio and Streamable HTTP bindings.
The [stdio binding](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio)
uses newline-delimited UTF-8 JSON-RPC over a client-launched process. Stdout is protocol
only; stderr can be captured by clients and must also be redacted. Bound frame size,
request concurrency, response size and shutdown handling in PR-17.

[Versioning](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning)
distinguishes current per-request version/capability metadata and `server/discover`
from legacy `initialize` sessions (2025-11-25 and earlier). The roadmap's
"initialization" requirement is a lifecycle/compatibility requirement, not a license
to assume one handshake for every version. PR-17 must pin supported versions and
SDK/parser behavior after checking actual target clients, test unknown versions and
legacy handling, and reject unsupported versions explicitly. Supporting both eras
is a reviewed choice, not a claim that today's clients implement the latest spec.
No SDK/version or client compatibility is claimed verified in PR-02.

## Identity, authorization and revocation

Stdio pipes, a client label, parent PID, filesystem path, protocol metadata or
knowledge of a connection UUID do not authenticate a MacHandle connection.
Code signing identifies our helper, not the third-party application controlling its
stdin. Even a correctly signed helper can relay malicious requests.

Use two checks: authenticate the shipped IPC peer, then bind a locally authorized
connection to the specific helper channel/launch. Public
[XPC peer code-signing requirements](https://developer.apple.com/documentation/xpc/xpc_connection_set_peer_code_signing_requirement(_:_:))
are available at the chosen floor (macOS 12+, SDK check and Swift typecheck).
The broker and helper must verify their expected peer before sensitive exchange;
requirement-installation errors fail closed. A requirement must include the reviewed
signing authority and identifier, not identifier alone. Actual signed requirements,
service visibility and rejection behavior remain PR-17 tests. Do not use a racy
PID lookup as proof of the sending process's signature.

PR-19's minimum safe activation is local per-launch pairing/confirmation bound to
that channel, selected policy and a revocable server-side connection record. Unknown
launches default denied. A persistent unattended pairing option needs separately
proven client binding and secure credential provisioning; an environment variable,
plaintext MCP configuration token or a helper-wide Keychain secret is not sufficient.
A new helper invocation must not choose an existing trusted identity via arguments.
No automatic reconnect is promised until that isolation is demonstrated.

The broker derives identity from authenticated channel state, checks enabled status,
resource selection, operation and visible fields for every request, and returns only
filtered values. A policy generation/revocation epoch invalidates cached decisions
and pending approvals. Revoke disables new work immediately, closes channels and
cancels queued work; recheck before provider dispatch and before returning content.
Already delivered content cannot be recalled, and a write already accepted by a
provider may finish. Report that boundary honestly; do not promise rollback.

PR-20 binds local approvals to connection, policy generation, exact target/arguments,
expiry, single use and mutation preconditions. Consume approval atomically with
admission to serialized execution; revalidate current provider state. Transport retry
must not replay a mutation. Provider-level races still need PR-21 conflict/recovery
handling; a request ID is not an authorization or idempotency guarantee.

## Alternatives, tradeoffs and consequences

Giving each MCP process provider/Keychain privileges simplifies routing but multiplies
TCC owners and bypass paths. One broker centralizes authority and revocation at the
cost of lifecycle/IPC complexity. An in-process SwiftUI transport couples UI lifetime
to client process management; a separate adapter preserves the specification boundary.
A loopback HTTP broker would add listener authentication, binding/origin and DNS
rebinding concerns; do not introduce it merely to avoid proving sandbox-compatible IPC.

The same-user threat boundary has limits: sandbox/signature checks do not establish
that a compromised authorized client is benign, nor prevent it disclosing already
returned data. Pairing is an access decision, not process attestation. Bound outputs,
local approvals and minimal fields reduce exposure without a claim of immunity to
same-user malware. Resource text remains inert input and cannot authorize anything.

| Gate | Owner / closure evidence |
| --- | --- |
| Signed external helper reachability and peer rejection, sandbox/TCC ownership, crash/restart | PR-17; synthetic packaged processes on minimum/current OS, no personal data. |
| Actual supported client/protocol matrix, EOF/cancel/errors/limits | PR-17 with mock tools only. Refresh current official spec then. |
| Pairing, impersonation, reconnect, concurrent channels, revoked cached policy | PR-19; adversarial synthetic tests before PR-18 reads are activated externally. |
| Approval replay/alteration, stale version and revoke-during-operation | PR-20/21 before real mutations. |
| Remote TLS/auth/origin/binding/tunnel/offline security | PR-28 only; optional and independently gated. |
| Independent security review of public write-enabled MCP | PR-29/30 before distribution. |

No MCP runtime or public compatibility is established by these design decisions.

## Work package 17 follow-up

[ADR-0022](0022-mcp-server-foundation.md) implements an isolated synthetic stdio helper,
explicit modern/legacy protocol handling and a bounded mock registry. It establishes no
caller identity, IPC trust or provider authority. Signed packaged broker proof remains
owned by engineering/maintainer after approved identity setup; it is not waived by SDK
interoperability. Package 18 adapters remain externally disabled until that proof and
package 19 identity/revocation gates pass.
