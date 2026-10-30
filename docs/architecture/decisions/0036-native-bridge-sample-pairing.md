# ADR-0036: Native read broker and sample XPC pairing

Date: 2026-10-30. Status: implemented for review; signed external-helper activation remains closed.

## Context and decision

GitHub PR #32 merged at `34ad4c3e4e0165123cda48b9b3808adab8e7fd36` on 2026-10-29
16:52:36 UTC. Both hosted gates passed on `ac5ec5507a74d3cffcf6a31bdf1f73d0e4908465`.
The user authorized the next native bridge PR using sample data, with personal iCloud untouched.
This is a bounded follow-up to the original 31 packages, not a renumbering of their requirements.

Add NativeMCPBridge as the app-side composition boundary between native administration,
MCPConnections and the existing policy-filtered Reminders adapter. Its broker binds one trusted
channel and candidate; native review/approval are package-only methods, absent from the wire.
Only the fixed SampleBridgeSession factory is used by the native presentation model. It creates
memory settings, a synthetic OS observation and synthetic peer plus the existing sample provider.
It cannot select a live provider or accept a client-supplied identity/grant.

Apple's [anonymous listener](https://developer.apple.com/documentation/foundation/nsxpclistener/anonymous())
and [listener endpoint](https://developer.apple.com/documentation/foundation/nsxpclistenerendpoint)
documentation, checked 2026-10-30, describes connecting with an endpoint object. Use an unpublished
anonymous NSXPCListener and one NSXPCConnection within the app/test process to exercise real XPC
serialization, callbacks and invalidation. No named Mach service, launch agent, endpoint exchange,
network port, sandbox exception, signing identity or external client is configured. The anonymous
endpoint is not exposed. Possession of an endpoint is not authenticated peer identity.

## Boundaries and lifecycle

The XPC interface has one bounded Data request/reply method. Version 1 accepts only `version`,
`tool` and `arguments`; it has no connection selector, pairing approval, policy update or mutation.
Reuse the strict MCP parser (duplicate-key, depth and node rejection) and tool argument validation.
Only the three Reminders read tools are registered. The sample grant allows selected-list discovery
and summary titles/completion; detail requests have no grant. Notes, other lists and writes remain denied.

Admission is denied before approval. Native controller reviews retain their 60-second expiration,
nonce/revision checks, one-time consumption and exact-channel binding. Broker checks the lease after
suspended work and immediately before returning an encoded response. Transport checks closure again
before reply/callback completion. Revocation cannot recall content already delivered.

Requests are bounded to 16 KiB, replies to 32 KiB, with four admitted server tasks and the existing
lease read budgets. These limits apply after Foundation has decoded the XPC Data argument; this
fixture transport is not a hostile cross-process allocation defense. Client calls have a two-second
deadline; cancellation/timeout/error/interrupt/invalidation closes admission and the connection.
Completion arbitration resumes once even if cancellation precedes continuation installation or a
late reply races timeout. Uncooperative provider work retains existing controller budget until return.
All errors sent across the wire are fixed codes, never exception/provider text.

Native Connections adds an opt-in rehearsal with local review, sample reads, disconnect and revoke.
Leaving the view clears the sample session. New launches require a new review. UI generation checks
prevent completed work from repopulating results after a stop. No sample pairing or grant survives
restart; no permission prompt or personal-provider read is involved.

## Alternatives and consequences

- A pure mock transport would miss XPC encoding and invalidation behavior. Anonymous XPC provides
  useful runtime evidence without registering a system service, but both endpoints are in one process;
  it cannot close external launch, signed peer, sandbox/TCC or minimum-OS acceptance.
- Wiring the existing stdio helper to an unsigned named broker would expand exposure before peer
  identity and discovery are proven. Keep `machandle-mcp --synthetic` unchanged; no fallback bypass.
- Reusing the existing adapter/parser avoids a second permission or wire-validation implementation.
  Package visibility is widened only for trusted composition; external-module negative probes remain.
- Read-only Reminders are the first slice. Calendar/Contacts, writes, persistence and auto-reconnect
  remain separate reviewed additions; their existing requirements are preserved.

## Evidence and remaining gates

See [acceptance](../../implementation/prs/native-bridge.md#implementation-and-acceptance) and the
[developer protocol](../../development/native-bridge.md). Tests use only synthetic values, including
an over-returned hidden note and suspended provider. No real iCloud data, account setup or signing.

Engineering owns the next signed external-helper → broker prototype: choose/prove supported scoped
service discovery, install mutual authority-and-identifier signing requirements on the actual peer,
connect current OS observations, and prove rejection/restart/lifecycle on minimum/current macOS.
Maintainer owns approved signing identity and authorization of isolated fixture setup. Revisit once
that setup exists. ADR-0006/0024 gates remain open; a synthetic `true` verification closure may never
be carried into live composition. Public ChatGPT, remote R1–R6, Notes G1–G6 and release P1–P5 remain open.
