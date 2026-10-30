# ChatGPT compatibility and distribution decision

## Private desktop update — 2026-10-30

[Slot 5](../implementation/prs/private-reminders-slot-5.md) now owns the bounded synthetic Reminder
experiment using documented direct STDIO configuration in ChatGPT desktop's local Codex chat surface.
See the [desktop runbook](private-desktop-client.md) and [ADR-0042](../architecture/decisions/0042-private-desktop-sample-client.md)
for setup, actual-client evidence and cleanup. This is not a marketplace plugin, public approval,
web/mobile integration or live Apple-provider activation. Public/remote/recurring gates below remain.

## Historical work package 31 decision

Checked 2026-10-29. Work package 31 implements [ADR-0035](../architecture/decisions/0035-chatgpt-distribution.md).
**MacHandle is not an installable or approved ChatGPT plugin.** No client installation, account
inspection, endpoint, submission or scheduled run was performed. The helper serves synthetic fixtures;
neither its protocol tests nor the native sample connection UI proves ChatGPT compatibility.

## Supported paths versus MacHandle readiness

The following are dated documentation findings, not confirmation of this maintainer's entitlement.
Check the intended account, client version, workspace permissions and security restrictions before
choosing a route. Do not purchase a plan on the assumption that it closes a MacHandle gate.

| Path | Documented platform boundary | MacHandle disposition |
| --- | --- | --- |
| Private desktop plugin | Local plugin packages can be installed/tested through a local marketplace in the desktop app [1] | Preferred first client experiment after the signed local bridge; not packaged, installed or tested here |
| Workspace sharing | Publishing requires workspace admin permission and stays within that workspace, separate from public directory publication [1] | Optional later choice; no workspace access inspected or changed |
| Private web MCP | Custom MCP setup accepts a server URL or Secure MCP Tunnel, with workspace/security restrictions and read/write tools [2] | Remote R1–R5 remain open; no endpoint or auth service exists |
| Public desktop MCP | Desktop-only local execution; local MCP submissions require an approved partner organization allowlist [3] | Eligibility unknown; no representative contact, allowlist, review or approval established |
| Public remote MCP | Stable public HTTPS endpoint, verified publishing identity and submission/review workflow [4] | Not selected; remote R1–R6 and release P1–P5 remain open |
| Recurring tasks | Web tasks can use plugins available to the chat; desktop local work requires the computer on and app running [5] | MacHandle scheduling unverified on every surface; foreground success would not close this gate |

[1]: https://developers.openai.com/plugins/build/plugins
[2]: https://developers.openai.com/api/docs/guides/custom-mcp-server
[3]: https://developers.openai.com/plugins/deploy/desktop-only
[4]: https://developers.openai.com/plugins/deploy/submission
[5]: https://learn.chatgpt.com/docs/automations

The [custom MCP guide][2] does not establish a plan entitlement for this account. Record the actual
plan/workspace and whether creation, installation, each tool class and scheduling are available during
authorized acceptance. Lack of observed entitlement means unknown, not unsupported or approved.
Read/write support is subject to client confirmation settings; MacHandle must still enforce its own
identity, resource/field grants, revocation and exact local approval. Remembered ChatGPT confirmation
cannot authorize a native mutation. No mandatory search/fetch shim or additional Google scope is needed
to describe the existing tools. Any future adapter must preserve trusted policy checks.

## Packaging and setup sequence — future, not performed

1. Choose private desktop testing first unless a reviewed requirement needs web/remote access. Complete
   the signed broker/native pairing gates in [ADR-0024](../architecture/decisions/0024-mcp-connection-identity.md)
   with an isolated macOS test user and synthetic records. Keep personal iCloud untouched. A plugin
   manifest cannot turn the current synthetic helper into an authorized provider bridge.
2. Recheck platform eligibility and current schema. The [package guide][1] describes portable root
   `plugin.json` and `mcp.json`; its legacy compatibility format differs. Package only a reviewed,
   versioned executable and dependencies after its native boundary works. No manifest, marketplace,
   skills prompt, launch command or plugin ZIP is shipped by this decision. Never bundle secrets,
   personal data, developer-home paths or a prompt that claims authority to bypass local review.
3. For an explicitly selected remote route, complete [R1–R5](remote-mcp.md#activation-matrix) first.
   Then follow the official custom-server setup: choose URL/tunnel, configure authentication, install
   and select the plugin [2]. MacHandle requires authenticated access even when the platform offers
   unauthenticated options. A private test does not authorize public exposure or publication.
4. Run the acceptance protocol below, starting with discovery and selected reads. Keep each Apple
   permission independent and opt-in; enable no writes until signed/native approval and provider
   conflict/recovery checks pass. Notes remains unavailable under G1–G6. Google is optional.
5. Only if public distribution is later requested: follow the selected route's prerequisites. Public
   submission requires organization owner or Apps Management Write access and individual or business
   identity verification; submit for review and publish only after approval [4]. Desktop local MCP
   additionally needs confirmed partner allowlisting [3]. No company ownership or eligibility is
   assumed. Use [account preparation](account-release-checklist.md), not credentials in a PR.

## Future acceptance protocol

All cases below are **proposed and unexecuted**. Engineering records exact app/helper SHA, signed
identity, OS/client/protocol version, surface, account entitlement and scoped results privately without
tokens or content traces. Maintainer authorizes isolated setup; no personal records are fixtures.
The submission guide requires five positive and three negative cases for initial MCP app review [4];
confirm applicability to the chosen submission route, especially the separate desktop-only flow.
These eight candidates are a test design, not submission metadata or a claim of review readiness;
map them to the final advertised tool names/schema and refresh requirements before submission.

| Case | Fixture action and required observation |
| --- | --- |
| Positive 1 | Discover only the resource types and selected test calendars granted to this paired connection; unrelated fixture resources remain absent |
| Positive 2 | Request availability for a fixed selected-calendar interval; expected busy ranges appear without event titles or hidden fields |
| Positive 3 | Read selected fixture Reminders after a separate Reminders grant; Calendar or Google grants alone confer no access |
| Positive 4 | After separate write acceptance, propose a bounded fixture Reminder change, approve its exact native review, commit once and independently observe the expected effect |
| Positive 5 | Reconnect a still-authorized client and repeat a bounded read with current policy; no remembered permission substitutes for current checks |
| Negative 1 | Guess an unselected resource/hidden field or inject instructions through fixture text; deny access without leaking data or widening grants |
| Negative 2 | Revoke/disable the connection or revoke OS permission during a request; reject delivery/commit and require fresh valid authorization |
| Negative 3 | Alter, expire or replay a proposal, or remember ChatGPT approval without native confirmation; no unauthorized effect or duplicate mutation |

Read-only acceptance may proceed without Positive 4 only as a clearly scoped private experiment.
It cannot establish write support or complete this proposed public review set. Signed peer rejection,
crash/unknown-result containment, cross-client isolation and provider conflict checks remain mandatory
under the existing local/remote gates; eight client cases do not replace them.

Independently test the original [hangout use case](../product/master-spec.md#87-original-hangout-reminder-use-case)
with fixture personal availability, a fictional friend's work schedule and a fixed sports schedule.
First prove a foreground comparison, then an explicitly authorized recurring task on the intended
surface. Verify repeated runs, time zone/DST, permission loss, asleep/offline Mac, reconnect and
cancellation. An unavailable source must not become an empty/free calendar. Observe actual task
results and any delivery separately; do not infer availability from a prompt or create a task now.
The [scheduling documentation][5] establishes possible platform mechanisms, not MacHandle support.
Unattended execution cannot skip native write approval, and no MacHandle app-event trigger is claimed.

## Owned deferral and revisit trigger

Plugin packaging/installation, actual ChatGPT compatibility, public review/publication and recurring
compatibility are deferred. Engineering owns bridge, package and client verification; the maintainer
owns account/identity choices and explicit setup/submission authorization. Revisit after signed local
pairing/read proof and confirmed client eligibility, or a material supported-platform change. Public
work additionally requires the chosen route's eligibility plus [P1–P5](release-engineering.md#owned-release-gates).
Remote work additionally requires R1–R6. Native Notes requirements retain their separate G1–G6 gates.
See the [activation backlog](../implementation/activation-backlog.md) for bounded next choices.
