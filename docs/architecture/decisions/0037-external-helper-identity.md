# ADR-0037: Account-free external helper identity proof

Date: 2026-10-30. Status: implemented for review, **slot 1 acceptance still open**.
Prerequisite: GitHub PR #33 merged at `94df5e5b1654268d711f4cd2bf498163e73e028d`.
Read [slot 1](../../implementation/prs/private-reminders-slot-1.md) and the
[bounded private testing plan](../../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line).

## Decision and evidence

Add a package-internal LocalBridgeTransport, a minimal external read-envelope probe and a separate
sample broker. Use public NSXPCConnection/NSXPCListener signing requirements on the actual XPC
channel, installed before resume. The SDK headers mark both Foundation APIs available on macOS 13,
within our macOS 14 floor. Parse requirements with Security before passing them to Foundation
(which raises an Objective-C exception for malformed syntax). Accept only constructed, bounded
requirements; raw expressions are not a public/wire input.

The negative runtime check caught an important distinction: these requirements validate received
messages, including replies; setting the client's requirement alone did not prevent its first request
from reaching an unexpected broker. The client now requests a content-free version handshake before
**each** read envelope. Only after the OS accepts that reply does it forward content on the same
connection. No provider/pairing factory runs for the handshake. There is no reconnect between these
steps; interruption permanently closes the client. The rejection test checks the broker marker as
well as the helper's returned error, preventing a false pass based only on reply rejection. This is
not attestation of an uncompromised peer; a compromised authorized binary remains outside that claim.

Two explicit identity forms exist: Apple generic anchor + leaf team OU + identifier for future
trusted composition, and exact code hash + identifier for this account-free fixture. The team form
has syntax tests only. The fixture harness copies built executables into a mode-0700 temporary
directory and ad-hoc signs **only those copies**, requiring no certificate, Keychain query, developer
account, employer team or private key. Changing either the peer hash or identifier fails closed.
A code hash pins one build, not a publisher or stable development identity.

[Apple's XPC overview](https://developer.apple.com/documentation/xpc) distinguishes embedded services
(one process per client) from a per-user launch agent. An embedded service cannot simply be assumed
to be the native app's shared broker. For this proof, explicitly bootstrap a uniquely named per-user
**GUI session** Mach service from a temporary plist. The probe is launched independently by Python,
not as a broker child. No root daemon, network socket, permanent Library install, login item, app
group or entitlement exception is added. Existing app sandbox/hardened-runtime settings are unchanged.
This SwiftPM fixture is unsandboxed; it is **not** the shipped app's packaging or sandbox proof.
The per-user `user/UID` bootstrap attempt failed on the development host; `gui/UID` succeeded.
The harness therefore requires an active GUI session and fails visibly elsewhere, without fallback.

The harness verifies both directions and checks a content-free broker-dispatch marker: rejected peers
must not reach the broker factory. Successful sample discovery/search proves a real process boundary,
not just requirement parsing. A second helper cannot reuse the first channel's approval. An approved
fixture can read selected titles/completion; a denied fixture cannot. Extra wire approval keys,
mutation names, hidden notes and broker absence/termination remain denied. Every temporary launchd
job is booted out and checked absent in `finally`; fixture executables/plists/markers are removed.
The broker also exits after 60 seconds if a supervising test fails. A forcibly killed harness can
still leave its temporary job registered; the runbook gives exact-label cleanup without broad pruning.

## Trust and bounds

LocalPeerGate starts unauthenticated and can be opened only by transport code after the checked
incoming method is delivered. Closing is irreversible. The native broker's ConnectionChannel checks
this exact gate, not `verify: { true }`. Broker authority continues to live in NativeMCPBridge and the
existing controller/adapter; the probe has no provider, policy, approval, persistence or credential
dependency. Import/dependency guards and negative compiler probes maintain that separation.

The wire remains the version-1 bounded read envelope from ADR-0036, with no administration methods.
The separate sample executable makes an explicit harness-local approved/denied decision. It does
**not** represent native user consent. Its only source is fixed synthetic reminders; neither the app
nor production code loads fixture CLI arguments. The sample factory is not selectable from the app.

One accepted channel per listener, four admitted requests, 16 KiB requests, 32 KiB replies, two-second
client deadlines, cancellation and interruption/invalidation all fail closed. Closing the gate blocks
reply delivery before asynchronous broker cleanup. There is no retry/reconnect or identity fallback.
Foundation decodes Data before size checks, so these limits are not a hostile allocation defense.
The probe bounds newline frames and is restricted to pipes, at most 16 calls and finite I/O waits.
It is a **probe**, not an MCP stdio server; `machandle-mcp --synthetic` remains unchanged.

## Alternatives and consequences

- Another in-process mock would not establish cross-process identity rejection. Actual local ad-hoc
  signatures provide useful kernel-enforced proof without borrowing an employer identity or requiring
  paid enrollment. They do not close team-signed or distribution acceptance.
- Identifier-only requirements, caller labels/PIDs/paths, plaintext tokens and unchecked fallback are
  rejected. A matching helper still does not identify the third-party program controlling its stdin.
- A permanent launch agent, disabling the app sandbox, or adding global Mach lookup exceptions would
  prematurely choose a deployment model. This opt-in harness evaluates discovery without those changes.
- Replacing the native app with the sample broker would bypass native consent/TCC ownership. Do not
  connect personal data or advertise this probe as the product helper.

## Remaining slot 1 gates and owners

Engineering owns supported sandbox-compatible discovery, packaged app/native per-launch approval
handoff, a real minimal MCP relay, and minimum/current OS evidence. Personal-use scope is confirmed:
first evaluate owner-controlled local signing, including exact-build pins, without treating a paid
team as a prerequisite. A reviewed private-build identity strategy still needs runtime evidence; this
fixture alone does not establish it. The maintainer owns approval of isolated runtime setup when ready.
Employer signing resources are not used. Public distribution identity and monetization are outside
this private finish line. If a specific needed capability actually requires paid enrollment, document
that requirement and alternatives before proposing a purchase; an open technical gate is not proof
that a membership is needed.
Revisit these gates before slot 2/provider activation; no live factory is opened by this PR.
If they require additional PRs or a changed private-testing route, revise the six-slot plan explicitly
with the user before proceeding. Do not count this partial proof as completed slot 1.

The intended client route is documented local desktop stdio configuration (ChatGPT desktop preferred),
with account/surface policy and actual install still unverified. See the [runbook](../../development/external-helper.md).
Public plugin eligibility, remote, Notes, Google and distribution remain separate existing gates.
