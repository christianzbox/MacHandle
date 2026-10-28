# ADR-0022: Bounded synthetic MCP server foundation

Date: 2026-10-28. Status: implemented for work package 17 review; live broker activation
and signed packaging remain gated. Requirements: [PR-17](../../product/master-spec.md#pr-17--mcp-server-foundation),
[§8](../../product/master-spec.md#8-mcp-and-ai-integration).
See [ADR-0006](0006-local-mcp-and-processes.md), [ADR-0009](0009-permission-policy-engine.md),
[acceptance](../../implementation/prs/pr-17.md#implementation-and-acceptance) and
[developer procedure](../../development/mcp-foundation.md).

## Decision and dependency boundary

Add an isolated MCPServer Swift target and a minimal `machandle-mcp` executable. The
executable requires `--synthetic`; no arguments select a connection, account or provider.
The only registered tools are `mock_add`, `mock_fail`, `mock_status` and `mock_wait`.
Integer arguments, required names, unknown-key rejection and generated input schemas
share the same typed field definitions. Registry names/fields are validated and tools
are listed deterministically. Responses include text and structured content; execution
failure is a fixed tool error, distinct from malformed protocol/argument errors.

The protocol actor, registry, JSON representation and transport implementation are
internal. The package-only executable composition installs fixed mocks. There is no
CoreDomain, PermissionEngine, provider, Google, Keychain, database or SwiftUI dependency,
no app embedding, broker endpoint, service registration, permission prompt or listener.
Compiler/dependency checks enforce that boundary. A future broker adapter must perform
its own authenticated channel binding and policy checks; tool metadata cannot confer them.

## Protocol compatibility and evidence

Official sources were refreshed on 2026-10-28. The current
[versioning model](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning)
and [metadata contract](https://modelcontextprotocol.io/specification/2026-07-28/basic/index)
require per-request information; this cannot be inferred from a previous handshake.
Implement an explicit, limited dual-era profile:

| Profile | Behavior |
| --- | --- |
| 2026-07-28 | Validate version and capabilities on each request, optional client info when present; implement discovery, ping, tool listing/calls and cancellation. Results carry complete-result metadata. Discovery/listing use zero TTL and private cache scope. |
| 2025-11-25 | Initialize, return the supported legacy version, then require initialized notification before tools. Ping remains available. Other requested legacy versions receive the supported version; the client must accept it or disconnect. |
| Unsupported/malformed modern request | Explicit unsupported-version error with supported list, or invalid-parameters error for missing/wrong metadata; never reinterpret it using cached legacy capabilities. |

The [discovery](https://modelcontextprotocol.io/specification/2026-07-28/server/discover),
[tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[legacy lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
and [cancellation](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/cancellation)
contracts guide these cases. No resources, prompts, subscriptions, sampling, elicitation,
tasks, logging capability, server-initiated requests, HTTP or remote authentication are
advertised. Unsupported methods fail explicitly. Client names/capabilities are display/
protocol input, not authenticated identity. Modern requests do not acquire authority from
legacy initialization. This is a tested feature profile, not full-protocol conformance.

Independent official TypeScript clients passed discovery/initialization, four tool schemas,
structured addition, tool errors and close: `@modelcontextprotocol/sdk@1.26.0` in legacy
mode, and `@modelcontextprotocol/client@2.4.0` in pinned-modern and automatic modes.
SDK testing exposed required cache metadata and Node's use of local stream socket pairs;
both are supported. It did not configure or test actual Codex/Claude desktop releases.
The durable supplemental script and exact commands are in the developer procedure.

## Framing, concurrency and shutdown

Follow the official [stdio binding](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio):
UTF-8 JSON-RPC frames on stdout only. All diagnostics are fixed, content-free text;
caller arguments, cancellation reasons, frame bodies and raw exceptions are never logged.
Unknown notifications and notifications with invalid parameters receive no reply; malformed
JSON/envelopes receive fixed protocol errors. Batches and client responses are unsupported.

| Bound | Enforcement |
| --- | --- |
| Input/output | 64 KiB per JSON frame, excluding delimiter; 4 KiB input reads; oversized/partial-at-EOF frames terminate. Invalid JSON in a complete bounded frame gets a fixed parse error. |
| JSON structure | Depth 32, 4096 values; reject invalid UTF-8, non-finite numbers, duplicate keys including escaped aliases and trailing syntax. Scalars are decoded by Foundation after structural bounds. |
| IDs/registry | String IDs 1–128 UTF-8 bytes; numeric IDs are safe integers. Up to 32 tools, 16 integer fields per tool, validated names. Four shipped tools only. |
| Work | At most four pending tool calls, including cancelled calls until they finish. Shipped mock work is cancellable and lasts at most one second. No unbounded execution queue. |
| Legacy history | Retain at most 4096 request IDs; reuse/overflow ends the legacy session. Modern IDs may be reused after completion; duplicate active IDs end the channel. |
| Output pressure | Dedicated serial writer prevents frame interleaving; a two-second write deadline closes a stalled channel. Cancellation suppresses unsent output; partial output forces closure. |

Read readiness blocks on a dedicated queue with a wake pipe, avoiding periodic idle polling.
Endpoints must be pipes or local stream sockets, never regular files, terminals or network
sockets. EOF, SIGTERM and SIGINT close admission, wake blocked I/O and cancel/drain owned
work. A fatal output failure also wakes an otherwise idle reader. Already dispatched bytes
cannot be recalled. The process has no durable requests to replay after restart.

## Alternatives and consequences

The [official Swift SDK 0.12.1 manifest](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Package.swift)
was inspected. Adopting it would bring a broader transport/dependency surface than these
four synthetic tools require. Use a small Foundation-based profile with explicit bounds
now; this increases our responsibility for parser/protocol maintenance and requires
independent client checks. Revisit SDK adoption before expanding optional MCP features;
this decision is not a judgment that the official SDK is unsafe. No npm/Swift SDK becomes
a runtime dependency; npm clients are disposable supplemental test dependencies only.

A line-oriented convenience reader without a length bound was rejected. Running handlers
serially inside the read loop was rejected because it would prevent timely cancellation.
Unbounded tasks/output queues and a listener-based shortcut were rejected. The helper is
not embedded in the signed app just to claim packaged interoperability.

## Remaining signed/live gate

ADR-0006's signed external launch → authenticated broker proof remains open. No approved
team/registered identity was supplied; no signed IPC harness or code-requirement proof is
claimed. Engineering and the maintainer own this follow-up when a development identity is
available, before any personal-data activation: prove scoped service reachability, mutual
peer rejection, app absent/restart/denial, minimum/current OS and actual supported clients.
Do not introduce Mach lookup exceptions, shared credentials, app groups or weakened sandbox
settings to bypass it. Package 18 can develop synthetic policy-filtered read adapters;
external real reads still require package 19 identity/revocation and this packaging proof.
Google's separate activation ledger stays open. No milestone C or distribution acceptance
is inferred from an unsigned standalone mock process.
