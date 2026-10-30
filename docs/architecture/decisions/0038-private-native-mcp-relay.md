# ADR-0038: Account-free private native app and MCP relay

Date: 2026-10-30. Status: implemented for review, current-Mac sample acceptance.
Prerequisite: GitHub PR #34 merged at `c63bee0419aea526761795fe93f02bf767b282cf`.
Requirements: specification §8 and §13.4; [slot 1 brief](../../implementation/prs/private-reminders-slot-1.md).

## Decision

Finish slot 1 with a dedicated **MacHandle Private** sample app and a minimal external stdio MCP
relay in its bundle. The private app is a native SwiftUI executable using MacHandleApplication and
NativeMCPBridge. Its dependency graph contains no EventKit/Contacts provider, Google authorization,
persistent store or native mutation writer. This permits real native approval and sandbox testing
without constructing a personal provider. The regular development app remains unchanged.

Keep the private app sandboxed with **only** `com.apple.security.app-sandbox`; apply hardened runtime
to it and the helper. A temporary GUI-session launchd job advertises the named service and launches
the app on demand. The app successfully checks into that service without Mach registration/lookup
exceptions, an app group, login-item install or root service. This is runtime evidence on the current
Mac, not an assumption based on embedded-service inheritance. The helper is an independently launched,
unsandboxed stdio executable with no special entitlements. It does not inherit the app sandbox; its
small dependency graph and validated protocol limit its implementation, not its OS file privileges.
A desktop client that imposes its own sandbox may still deny discovery; that actual-client acceptance
belongs to slot 5. Do not add entitlement exceptions or disable the app sandbox to bypass it.

Apple documents named [NSXPC connections](https://developer.apple.com/documentation/foundation/nsxpcconnection/init(machservicename:options:))
for launchd services and [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
constraints. Public SDK Security APIs provide running-code validation, certificate information and
[code requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
Sources and the runtime were checked 2026-10-30. No private Apple API or PID-based peer lookup is used.

## Local identity without an Apple account

Packaging generates a local self-signed code-signing certificate in a private temporary directory,
imports it into a **separate disposable keychain**, and signs both peers. It does not enumerate existing
identities, use an employer certificate, change the default keychain or system certificate trust, enroll
with Apple, notarize or contact a signing service. Private keys, passwords and the temporary keychain
are removed; command output and password-bearing arguments are never logged. Only the public signature
and certificate remain in the sample artifact. Ordinary CI performs none of this signing setup.

Each running peer obtains its own certificate and identifier through Security, validates that metadata
against the running code, and derives the exact expected sibling identifier. It then requires that
certificate fingerprint **and** sibling identifier on the actual XPC connection. The app bundle's code
and resource seal are checked against the running peer's certificate before reading the sample-only
configuration. The caller supplies neither peer authority nor policy. No certificate/identifier is
accepted from MCP, environment variables, a plaintext token or helper command arguments.

A unique identifier family per build avoids reusing a previous sandbox container with a different
signer. This is a disposable private test identity, not a stable upgrade/Keychain identity. The
certificate has seven-day validity; no timed authorization or automatic credential rotation is claimed.
Durable identity, update continuity and packaging for ongoing use remain slot 6 handoff work. An
appropriate local strategy can remain account-free; paid membership is not an assumed prerequisite.

The content-free, verified handshake from ADR-0037 remains mandatory before **each** read envelope.
XPC validates received messages, so reply rejection alone must not be mistaken for preventing first
request delivery. The listener authenticates its peer before native review creation. Knowing the Mach
service name or possessing a helper binary does not approve a connection.

## Native consent and MCP forwarding

The helper initially sends public list discovery only to request native review. No data is returned
before native approval. The app presents exactly the sample list/name/title/completion grant and the
existing controller's 60-second, single-use, channel-bound review. Allow, reject, revoke and closing
the window operate only through native presentation methods. Approval, policy and grant administration
are absent from both XPC and MCP. Disconnect/revocation closes the transport before asynchronous cleanup;
a second launch cannot reuse the first one's approval. New sessions start disabled.

ReminderMCPContract extracts the existing three read-tool schemas and bounded argument definitions so
the adapter and relay share one contract. It contains no domain/provider/policy administration. The
relay forwards validated read envelopes, parses bounded results, rechecks cancellation/connection
closure before stdio output, and uses the existing MCP server's framing, protocol and concurrency
limits. Broker/controller checks remain authoritative. No write tools or synthetic local fallback are
registered by this relay. The original `machandle-mcp --synthetic` behavior is preserved.

The private stdio profile identifies itself accurately and explains native sample approval. Client
metadata, tool descriptions, helper labels and resource text remain unauthenticated/inert. A signature
identifies the shipped helper, not the AI application controlling its stdin. Already delivered data
cannot be recalled, and a compromised authorized peer is not made benign by signature checking.

## Alternatives and limits

- Ad-hoc hashes work for the prior fixture, but mutually embedding changing peer hashes complicates
  reproducible app/helper packaging. A disposable, locally owned certificate supplies a common
  authority without borrowing a company identity or purchasing Apple enrollment.
- A caller-configured certificate/hash would let the caller choose trust. Derive authority from the
  running code and signed sibling bundle instead; missing/ad-hoc identity and tampered resources fail.
- A native UI in an unrelated mock would miss the approval handoff. The packaged sandboxed app owns
  the actual NativeReadBroker used by the external MCP client; no test-only approval endpoint exists.
- A permanent service install or live provider is unnecessary for slot 1. Temporary GUI registration
  and in-memory synthetic data provide scoped evidence; registration and app shutdown are checked on
  cleanup, with a bounded wait for launchd's asynchronous teardown.

The [acceptance runbook](../../development/private-native-bridge.md) includes real native clicks,
unapproved denial, selected reads, hidden fields, writes/approval-method denial, mismatched local
issuer, tampering, second-launch denial, revocation and cleanup. A readable synthetic canary outside
the app container must be denied; unexpected access refuses app activation. This proves that tested
access boundary, not all possible sandbox behavior. OS-managed sample containers may remain; no
personal iCloud container or content is read, modified or cleaned up.

## Slot boundaries

The authoritative private finish line is one designated Mac, sample data and a selected local desktop
client. Slot 1's missing technical path is now implemented and exercised on macOS 27.2. The macOS 14
floor compiles but was not runtime-tested here; engineering/maintainer retain minimum-OS acceptance
before expanding private test machines or making broader compatibility/distribution claims. Actual
ChatGPT/client installation belongs to planned slot 5, not this Python MCP test. Real isolated
Reminders reads belong to slot 2. No real provider, TCC or public-release gate closes here.

This explicitly resolves the prior brief's over-broad slot 1 references to minimum-OS and actual-client
acceptance against the agreed single-Mac/six-slot plan; those requirements are retained with the owners
and triggers above. Slot 1 used two authorized PRs. Five planned slots remain after review/merge;
no following slot, merge, publication, account setup or personal-data testing is authorized by this PR.

Slot 2 extends this with a separate selected-read app under [ADR-0039](0039-private-selected-reminder-reads.md); the original provider-free sample executable and its identity boundary remain.
