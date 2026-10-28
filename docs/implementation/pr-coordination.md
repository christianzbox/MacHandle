# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 23 acceptance](prs/pr-23.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 23 — Authorized Reminders management (legacy PR-23) |
| Branch | codex/authorized-reminders-management |
| GitHub PR | [GitHub PR #24](https://github.com/christianzbox/MacHandle/pull/24), open for review |
| Dependency | Work package 22, merged in GitHub PR #23 |
| Verified squash/base SHA | 1e09e40b92dcc9a1f18ab287e535e3f8f0d1c649 |
| Merge time | 2026-10-28 17:22:36 America/Detroit (21:22:36 UTC) |
| Authorization | User authorized package 23 after GitHub PR #23 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | 2e6ddaa2a5001f58f3a1cad522914cb79bfdf45c, pushed; final handoff SHA and repeated checks belong in the PR |
| Next action | Review GitHub PR #24; stop before merge or package 24 |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

Six approved Reminder operations, scoped observed-state binding, exact native reviews, separate
complete/uncomplete rights, durable intent/receipt journal and restart containment, gated EventKit
adapter, fixed native samples and two synthetic MCP proposal/commit tools. No wire confirmation
method exists; standalone helper proposals cannot execute. Existing read grants stay read-only.
[ADR-0028](../architecture/decisions/0028-reminders-management.md) records alternatives and constraints;
[developer checks](../development/reminders-management.md) separate synthetic and live evidence.

All three staged gates passed on the implementation checkpoint: environment 0.26 s, validation
50.81 s, secret scan 1.55 s. This includes 388 Swift tests, 23 Python checks and 40 negative compiler
probes. SDK legacy/modern/auto checks passed; 1073 documentation links passed. Native sample
uncomplete/deletion/cancellation and the corrected layout were inspected; app quit. Exact final-head
repeats and hosted CI are recorded separately in the PR.
No permission prompt, personal data, real writes, actual-client setup or production database used.
Engineering retains signed peer/native confirmation/current OS wiring, acceptable provider conflict
semantics, isolated real-list/minimum-OS/sandbox tests and unknown-result recovery. Recurrence/alarm/
list-move capabilities have explicit deferrals with evidence triggers. Calendar live writer stays
closed; Contacts package 24 is planned only; Notes retains its feasibility gate.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/authorized-reminders-management
# First use on another Mac: git switch --track origin/codex/authorized-reminders-management
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If merged, verify the actual squash SHA and wait for new direction; bookkeeping belongs in the next
authorized PR, never directly on main. Push safe checkpoints before switching Macs.

## Copyable next-session prompt

> Continue MacHandle work package 23 on codex/authorized-reminders-management and its linked PR.
> Read AGENTS, coordination/progress, ADR-0028 and acceptance. Preserve changes, fetch/fast-forward
> and confirm one writer. Prerequisite GitHub PR #23 merged at 1e09e40b92dcc9a1f18ab287e535e3f8f0d1c649.
> Address review feedback only. Keep independent Reminder policy/confirmation/journal, synthetic-only
> helper and all signed/live gates closed. No recurring/alarm/list-move expansion or Contacts/Notes
> implementation. Stage/review, run all three gates, commit/push the same PR, record exact local/hosted
> evidence and stop for review. No merge, auto-merge or release.
