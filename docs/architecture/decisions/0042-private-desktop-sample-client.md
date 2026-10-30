# ADR-0042: Temporary private desktop sample connection

Date: 2026-10-30. Status: implemented for review; actual desktop sample acceptance passed.
Prerequisite: GitHub PR #38 merged at `99f0fda1d571425be6984b09637e513d0356d24a`.
Scope: [slot 5](../../implementation/prs/private-reminders-slot-5.md), specification §8 MCP/native
approval and §20 testing. Supplements [ADR-0035](0035-chatgpt-distribution.md) for private foreground
desktop testing; public/remote/recurring requirements and deferrals remain unchanged.

## Decision

Use the existing signed sample-writes app/helper over local STDIO in ChatGPT desktop. Current
[official setup documentation](https://learn.chatgpt.com/docs/extend/mcp) supports Settings and
`codex mcp add`. No marketplace, remote tunnel, Apple/Google account or paid signing identity is
needed for this experiment. Installed metadata/documented support are not actual-session proof.

Separate preparation from activation. `desktop_sample.py prepare` packages only synthetic writes,
with a unique server name and reviewable command preview; it never launches/registers. Explicit run
flags allow one temporary GUI-session job and one client entry using the documented CLI. Native list
selection, signed pairing and exact single-use write approval remain mandatory. No new tool, approval
bypass, live provider or relaxed transport identity is introduced.

Verify sample profile, exact helper/arguments, signed mode/service and package signature before launch.
Refuse collisions; never print client configuration/command output that could contain credentials.
Remove only the unchanged owned entry, verify unrelated settings semantically, and unload the exact
job. Preserve user edits instead of restoring an old whole-file snapshot. Concurrent edits during CLI
writes remain a limitation; serialize those short steps operationally. SIGKILL needs targeted manual
cleanup; the launcher does not claim crash-proof rollback.

## Alternatives and consequences

- SDK/protocol tests cannot establish actual desktop discovery/routing/native round trips. Require
  real client tool calls plus independently observed readbacks and native journal counts.
- Marketplace packaging adds distribution work unrelated to private acceptance. Use direct STDIO;
  stable install/identity is slot 6, public packaging remains a separate decision.
- Whole-config replacement or global approval/sandbox changes risks unrelated work. Add/remove one
  random name and preserve other integrations and policy.
- Automatic reconnect/retry could extend old authority or duplicate uncertain effects. Native stop
  revokes access; fresh pairing/review remain required and unknown outcomes stay blocked.
- Another desktop client is an alternative only after explicit maintainer choice. Retain missing
  eligibility/tooling/IPC blockers rather than bypassing them or calling a probe actual-client proof.

## Verification and remaining gates

Synthetic tests cover collision refusal, interrupted/partially failed registration, changed-entry
preservation, concurrent unrelated settings, sample-only preparation, signature refusal and redacted
errors. The [desktop runbook](../../development/private-desktop-client.md) requires real discovery,
reads, six approved changes/readbacks, rejected/preapproval/replayed commits and revocation.
Report source/client versions, local/hosted CI and actual-client observations separately. A restriction
on computer-use control of the client is not a MacHandle failure; use supported capabilities or
maintainer-operated acceptance without circumventing that restriction.

Engineering owns client proof; maintainer owns client choice/explicit chat setup. Real EventKit/TCC
and conflicts remain gated under ADR-0040 with personal iCloud excluded. Stable handoff is slot 6;
minimum-OS and other-Mac runtime remain unverified.

The installed ChatGPT desktop local Codex chat passed the bounded workflow on 2026-10-30.
See [progress](../../implementation/progress.md) for versions, exact scope and cleanup. Other desktop
modes and plan tiers remain unverified; this is not a general ChatGPT plugin readiness claim.
