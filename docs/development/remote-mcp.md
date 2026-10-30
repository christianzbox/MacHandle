# Remote MCP readiness and activation evidence

Work package 28 implements the [ADR-0032](../architecture/decisions/0032-remote-mcp-readiness.md)
decision and an informational Connections notice. **Remote access is unavailable.** No HTTP listener,
OAuth resource server, tunnel, remote identity adapter or real-client acceptance is implemented.
The existing helper remains synthetic stdio only; its passing tests are not remote security proof.

## Compatibility matrix

| Surface | Evidence now | Remaining proof |
| --- | --- | --- |
| Local synthetic stdio | Existing 2026-07-28 and 2025-11-25 profiles, subprocess/SDK evidence in [foundation checks](mcp-foundation.md) | No signed broker, actual user pairing or personal data authority implied |
| Modern Streamable HTTP | Official specification reviewed; no adapter/server implemented | Header/body validation, request streams, cancellation, errors, limits and authenticated principal isolation |
| Legacy HTTP/SSE | Client documentation lists support; not implemented/tested here | Explicit negotiated compatibility and principal-bound legacy state; no assumption that legacy stdio support transfers |
| Private tunnel | Documented candidate; no account, key, process, tunnel or workspace inspected/configured | Authorized isolated setup, identity propagation, auth metadata reachability and real client read proof |
| ChatGPT reads/writes | Public interface documentation only | Actual intended workspace/client, scopes, field isolation and native approvals; write confirmation in ChatGPT is not MacHandle approval |
| Sleep/offline/reconnect | Required semantics recorded, no remote implementation | Fail unavailable, no stale success or late data; fresh authorization after reconnect; no write replay |
| Publication/scheduled tasks | No acceptance evidence | Package 31's separate platform/distribution decision; do not promise operation while the Mac is unavailable |

Current sources and their scope are linked in ADR-0032. Findings are dated 2026-10-29; refresh them
before implementation, especially client eligibility, transport versions and authentication support.

## Activation matrix

All rows are **deferred, not passed**. Owner: engineering unless stated otherwise. The trigger for
R1–R5 is maintainer authorization and an isolated synthetic fixture environment with approved identity
and remote-service configuration. No personal iCloud profile is a test environment. R6 additionally
requires a separate public distribution decision. Completing this work package does not activate them.

| Gate | Required evidence before closure |
| --- | --- |
| R1 — Route and accounts | Maintainer selects optional identity provider/resource identifier and tunnel or hosted route. Record approved environment, credential ownership, reachability, trust boundaries, cost/data-handling decisions and teardown. Do not commit keys, profiles or real identifiers. |
| R2 — Signed local bridge | Prove ADR-0024 signed peer rejection, native pairing, current OS observation, channel closure/restart and minimum/current OS behavior using fixtures. Remote adapter cannot call a synthetic trust factory or bypass local approvals. |
| R3 — Authenticated transport | Implement a reviewed supported protocol profile. Test expired/invalid/wrong-issuer/wrong-audience tokens, missing scopes, duplicate credentials, forbidden hosts/origins, hostile proxy headers, TLS errors, SSRF/discovery redirects and oversized/slow input. Authentication failure must reach no provider and leak no resource data. |
| R4 — Identity, policy and lifecycle | Test two owners/workspaces/devices, guessed/stolen handles, cross-client sessions, resource/field changes, revocation at each await, cancellation, sleep/offline and reconnect. Capture zero cross-principal delivery and no reactivation from saved labels or stale credentials. Verify global/per-principal limits. |
| R5 — Actual client and approvals | On the intended ChatGPT surface, record versions and a successful selected synthetic read plus denied hidden field/resource. Independently test exact local write review, altered/replayed/expired proposals, disconnect during confirmation, crash/unknown outcomes and no retry duplicates. Client remembered approval grants nothing locally. Start read-only; writes stay closed until separately proven. |
| R6 — Release and scheduling | Independent security review, user-visible remote data/retention explanation, credential rotation/revocation/cleanup, chosen distribution acceptance and separate recurring-task/offline behavior. Private custom testing is not public publication. |

Tests must record exact build SHA, protocol/client/OS versions, route and fixed synthetic outcomes.
Do not upload provider payloads, token traces, browser screenshots or personal account inventories.
Keep network experiments out of ordinary CI until an explicitly isolated, credential-free harness
is reviewed. A mock token validator cannot close R3; a synthetic peer cannot close R2; protocol
interoperability cannot close R5. No currently running tunnel or public endpoint needs cleanup here.

## Accounts and permissions to prepare later

Nothing must be purchased or granted to continue local development. Do not send secrets in chat.
For an authorized private-tunnel experiment, OpenAI documents separate Platform organization roles:
creation needs Tunnels Read/Manage; runtime needs Read/Use, plus the intended workspace association.
Obtain the least-privileged runtime credential only during approved setup. See the
[official tunnel guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels).

Separately choose an OAuth authorization service and app-specific resource identity, with discovery,
PKCE, token validation and revocation compatible with the target client. This project has not selected
or configured one. A Google Calendar OAuth client, Apple signing identity or OpenAI runtime key is not
a substitute for remote end-user authorization. Browser-facing auth reachability must be proven.
Use [existing Apple/Google setup guidance](google-auth-setup.md) for those independent prerequisites;
no new Google scope, Full Disk Access, Accessibility or Notes Automation is needed for this package.

Do not paste a tunnel command pointing at the current synthetic helper into a live client and call
that MacHandle integration. Future setup instructions must follow the reviewed R1–R5 implementation
and verified platform flow. No endpoint, tunnel, key or plugin is created by these documents.

Work package 31's [distribution matrix](chatgpt-distribution.md) now owns the dated packaging,
private/public eligibility and recurring-use investigation. Its explicit deferral does not close
R1–R6; the private tunnel remains a candidate, while private desktop acceptance can precede remote work.
