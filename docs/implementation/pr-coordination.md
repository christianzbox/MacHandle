# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 22 — Reminders provider and read operations (legacy specification ID PR-22) |
| Branch | codex/reminders-read-operations |
| GitHub PR | [GitHub PR #23](https://github.com/christianzbox/MacHandle/pull/23), open for review |
| Dependency | Work package 21, merged in [GitHub PR #22](https://github.com/christianzbox/MacHandle/pull/22) |
| Verified squash/base SHA | 9b5f01ccacd449ae3e1b00e5f29c2672692679d1 |
| Merge time | 2026-10-28 16:53:46 America/Detroit (20:53:46 UTC), verified before branching |
| Authorization | User authorized work package 22 after GitHub PR #22 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | 9eb43fd23cfbd51e8e77af011185b275fbd49571, pushed; final handoff SHA and repeated checks are recorded in the PR |
| Next action | Review GitHub PR #23; stop before merge or package 23 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Independent EventKit Reminders authorization/discovery, native opt-in/selected-list title search and
scoped details, explicit notes choice, async cancellation/late-result suppression, and typed due/
completion/recurrence-presence fields. Three new synthetic MCP read tools require independent paired
Reminder grants, project before search and revalidate before output. Settings v2 migrates v1 to no
Reminder grants. Google and Calendar permissions do not substitute; no Reminder writer is exposed.

All three staged gates passed: environment 0.33 s, validation 48.69 s, secret scan 1.78 s. This
includes 358 Swift + 23 Python checks and 35 negative compiler probes. Official SDK legacy/modern/auto
and 1041 local documentation links passed. Unsigned native inspection verified disabled access and
navigation without prompting; both built usage descriptions are present. Exact final-head reruns and
hosted outcomes are recorded independently in the PR.
See [ADR-0027](../architecture/decisions/0027-reminders-reads.md),
[acceptance](prs/pr-22.md#implementation-and-acceptance) and
[developer checks](../development/reminders-reads.md).

Engineering/maintainer retain signed TCC/sandbox/minimum-OS and isolated synthetic-list acceptance,
signed MCP peer/native pairing/current OS integration and actual-client/large-list checks. The helper
remains synthetic-only. No real permission, personal data, account or client configuration was used.
Package 21's live writer stays closed; [package 23](prs/pr-23.md) is preparation only, and Notes still
requires its feasibility gate.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/reminders-read-operations
# If already present: git switch codex/reminders-read-operations
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's GitHub PR/reviews/checks before editing. If merged, verify the actual
squash SHA and wait for new direction. Record bookkeeping in the next authorized PR,
never directly on main. Temporary logs stay outside Git.

## Copyable next-session prompt

> Continue MacHandle work package 22 on codex/reminders-read-operations and its linked PR.
> Read AGENTS, coordination/progress, ADR-0027 and the acceptance ledger. Prerequisite
> GitHub PR #22 merged at 9b5f01ccacd449ae3e1b00e5f29c2672692679d1. Preserve changes, fetch/fast-forward
> and confirm one writer. Address requested review feedback only. Keep independent Reminders
> permissions, synthetic-only MCP composition and signed/runtime acceptance gates. No Reminder
> writes or live Calendar mutation activation. Stage/review, run all three gates, commit/push the
> same PR and record exact local/hosted evidence. Stop for review; do not merge or start package 23.
