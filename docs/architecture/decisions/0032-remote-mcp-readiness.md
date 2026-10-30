# ADR-0032: Remote MCP candidate and deferred activation

Date: 2026-10-29. Status: work package 28 decision for review; remote activation deferred.
Requirements: specification §8.5–8.7 and PR-28. Extends
[process boundaries](0006-local-mcp-and-processes.md), [protocol foundation](0022-mcp-server-foundation.md),
[connection identity](0024-mcp-connection-identity.md) and [local approvals](0025-action-proposal-approval.md).

## Decision

Select authenticated private MCP behind an outbound tunnel as the first **candidate for a future
isolated experiment**, not a working integration. Defer activation: no approved remote identity/
authorization-server configuration, tunnel setup, signed broker bridge or actual ChatGPT acceptance
exists. These prerequisites require separately reviewed infrastructure/account choices and runtime
proof. Do not build a public listener or a mock authentication layer that could be mistaken for that
proof. Local features remain independent of hosted infrastructure, remote access and Google sync.

This package delivers the supported-path investigation, security/compatibility matrix, owned
activation gates and a static Connections notice. There is no remote transport/auth implementation,
network listener, tunnel client installation, credential, entitlement or connection configuration.
Existing synthetic stdio behavior is unchanged. Package 29 may proceed after this decision merges;
it cannot waive the deferred remote, signed-local, provider or Notes gates.

## Current official evidence

Sources inspected 2026-10-29; documentation availability is not account eligibility or live proof.

| Source | Scoped observation |
| --- | --- |
| [MCP Streamable HTTP 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http) | Modern requests use POST with JSON or request-scoped SSE responses. The revision removes protocol sessions/GET streams; required mirrored metadata must match the body. Origin validation, local binding and authentication matter. Older session-based HTTP needs explicit compatibility handling; stdio interoperability does not prove HTTP compliance. |
| [MCP authorization](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization) | Protected resources publish metadata, use resource-bound tokens and validate each request. OAuth client discovery/registration and issuer/resource checks are distinct from tool permission. Tokens for other audiences cannot be accepted or forwarded. |
| [MCP security guidance](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices) | Token passthrough, confused-deputy attacks, unsafe discovery URLs and state-handle theft need explicit defenses. Verified identity must bind state; caller-supplied handles or labels are not identity. |
| [ChatGPT custom MCP](https://developers.openai.com/api/docs/guides/custom-mcp-server) | Documents read/write tools, HTTP/SSE and a tunnel option, subject to workspace restrictions. Its confirmation UI is separate from MacHandle's trusted approval. This review establishes no eligibility, actual tool-call behavior or scheduled-task compatibility. Anonymous/mixed modes offered by the platform are not acceptable for MacHandle personal data. |
| [OpenAI authentication](https://developers.openai.com/plugins/build/auth) | Describes OAuth metadata, PKCE S256 and client registration choices. Client transport identity is not the resource owner's identity or consent. The documented OAuth setup has not been configured or tested for MacHandle. |
| [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) | Describes outbound forwarding to private stdio/HTTP servers. Requires Platform tunnel access, a runtime key and workspace association; transport does not replace app authorization. The authorization server is not automatically tunneled. Private tunnels are not a public-plugin distribution endpoint. |

The existing helper accepts only `--synthetic`, composes fixed fixtures and supplies synthetic peer
verification/local review. Exposing it through a tunnel would demonstrate fixture reachability only.
Never forward remote caller assertions into its synthetic trust seam or point it at real providers.
ADR-0024's actual signed channel verifier and native pairing remain unimplemented/unverified.

## Alternatives and consequences

| Route | Decision / tradeoff |
| --- | --- |
| Private HTTP resource adapter behind Secure MCP Tunnel | Preferred experiment candidate: retains a place to validate HTTP credentials before binding a broker channel. Needs approved OAuth provider/resource identity, provenance across the relay, signed broker and isolated acceptance. Adds an optional third-party transport and credentials; no automatic installation. |
| Tunnel directly to the existing stdio helper | Synthetic protocol demonstration only. No demonstrated authenticated end-user propagation or production broker authority. A shared subprocess cannot imply one shared personal-data principal. Not selected for live data. |
| Public HTTPS resource server/proxy | Possible future distribution route; requires hosting, TLS, authenticated routing, operations, security review and consent for data flow. No public infrastructure is established or required for local use. Deferred. |
| Raw port forwarding, anonymous endpoint or tunnel-key-only access | Rejected: reachability/control-plane credentials cannot establish owner, selection, operation or approval. Do not use Google credentials as remote MCP authority. |
| Local desktop stdio only | Existing synthetic helper remains available for development; live signed local access still has its own gates. It is not proof of remote ChatGPT support. |

A remote principal must bind to a single owner, local Mac installation and approved connection through
trusted code. Proposed flow: authenticated remote request → internal admission adapter → mutually
verified local broker channel → current policy/resource/field checks → provider. Never accept a wire
`user`, owner ID, connection name, forwarded header, session ID or resource text as that binding.
No shared global policy session across users or workspaces. The exact identity propagation and
credential-verification implementation is **unresolved**, not filled in with a Boolean test stub.

## Required security behavior before activation

These are project requirements for future code, not guarantees implemented by this PR:

- Verify token signature or trusted introspection, issuer, audience/resource, lifetime and scope at
  admission; reject unknown issuers, algorithms, ambiguous headers and duplicate credentials. Bind
  owner/device/connection server-side. Client or tunnel credentials alone never grant personal data.
- Keep remote connection enable, OS grants, resource selection, read fields, mutation grants and
  exact native approval separate. Client confirmation or remembered approval cannot mint a local
  confirmation. Begin actual acceptance with reads; remote writes need separate end-to-end proof.
- For HTTP, define TLS termination, exact host/origin allowlists, loopback/private binding, trusted
  proxy boundaries and rejection of hostile origins. Missing Origin from non-browser clients does
  not remove authentication. Validate forwarding headers only from an authenticated trusted hop.
- Pin a supported protocol profile, reject conflicting version/method/name metadata and bound frames,
  headers, decoded bodies, concurrency, rates and deadlines. No implicit legacy downgrade to escape
  validation. Bind legacy sessions and modern state handles to the same verified principal.
- Validate OAuth/discovery/CIMD destinations and redirects against SSRF, private/metadata targets,
  DNS changes and unsafe schemes; do not fetch arbitrary caller URLs. Remote data is inert content.
- Disable/revoke must close new admission immediately, cancel in-flight reads and suppress late
  results. Recheck authority before dispatch/delivery and after awaits. Separate local revocation,
  OAuth grant removal and tunnel shutdown; stopping one layer is not proof all are revoked.
- Offline, sleep or stopped MacHandle means unavailable, not an empty result. No stale success or
  cloud copy of personal content. On reconnect, expire old approvals and revalidate identity/policy.
  Timeouts after writes remain unknown; no automatic replay. Preserve journaled reconciliation.
- Return selected minimal data only. No tokens, bodies, source IDs or arbitrary provider errors in
  logs/support exports. Explain that authorized remote results leave the Mac; inspect relay/client
  retention and logging before activation. Already delivered content cannot be revoked retroactively.

## Owners and closure

Engineering owns protocol/auth/broker isolation and adversarial acceptance; the maintainer owns
approved app identity, isolated accounts, optional provider/tunnel infrastructure and credentials.
Security review precedes real data or public availability. The [R1–R6 matrix](../../development/remote-mcp.md#activation-matrix)
defines artifacts and revisit triggers. Revisit when those prerequisites are available or official
platform behavior changes; record a reviewed amendment per accepted subset. Do not infer eligibility
from a subscription, installed plugin, successful build or signed-in browser. Package 31 must verify
distribution and recurring-task behavior separately. No approval, publication or production readiness
is claimed here.
