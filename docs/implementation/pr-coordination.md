# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 20 — safe action proposal and approval engine (legacy specification ID PR-20) |
| Branch | codex/action-proposal-approval |
| GitHub PR | [GitHub PR #21](https://github.com/christianzbox/MacHandle/pull/21), open for review |
| Dependency | Work package 19, merged in [GitHub PR #20](https://github.com/christianzbox/MacHandle/pull/20) |
| Verified squash/base SHA | 77c3b797d403a5cfe957ac56d1b23f2c3462bea0 |
| Merge time | 2026-10-28 15:26:07 America/Detroit (19:26:07 UTC), verified before branching |
| Authorization | User authorized work package 20 after GitHub PR #20 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | 8026c86285b7e3358a3de27a621825cf250437e1, pushed; final handoff SHA and repeated gates are recorded in the PR |
| Next action | Review GitHub PR #21; stop before merge or package 21 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Exact retained Calendar proposals, local literal diffs, expiring single-use confirmation,
serialized mock dispatch and bounded content-free audit. Revalidation covers current policy,
channel/OS and provider state; unknown outcomes block further writes. Native sample create,
update/delete reviews cannot grant live access or change real calendars. MCP stays read-only.

Twenty engine tests plus two model tests bring totals to 319 Swift + 23 Python checks and
30 negative compiler probes. All three gates passed on the implementation checkpoint’s
staged tree: environment 0.20 s, validation 43.91 s, secret scan 1.56 s. Official SDK
legacy/modern/auto and unsigned native sample checks passed. Documentation checks passed
977 local links and 31 roadmap anchors. The PR records exact final-head reruns and hosted
results separately. See
[ADR-0025](../architecture/decisions/0025-action-proposal-approval.md),
[acceptance](prs/pr-20.md#implementation-and-acceptance) and
[developer checks](../development/action-approvals.md).

Engineering/maintainer retain approved identity, signed broker/native pairing/current OS and
actual client/minimum-OS acceptance. Package 21 also owns live write grants, provider conflict/
recurrence semantics, durable intent/recovery and native live-review wiring before real writes.
No real account/content, credential, permission or installed client configuration was used.
Google activation remains independent. [Package 21](prs/pr-21.md) is preparation only.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/action-proposal-approval
# If already present: git switch codex/action-proposal-approval
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's GitHub PR/reviews/checks before editing. If merged, verify the actual
squash SHA and wait for new direction. Record bookkeeping in the next authorized PR,
never directly on main. Temporary UI screenshots/logs stay outside Git.

## Copyable next-session prompt

> Continue MacHandle work package 20 on codex/action-proposal-approval and its linked PR.
> Read AGENTS, coordination/progress, ADR-0025 and the acceptance ledger. Prerequisite
> GitHub PR #20 merged at 77c3b797d403a5cfe957ac56d1b23f2c3462bea0. Preserve changes, fetch/fast-forward
> and confirm one writer. Address requested review feedback only. Keep mock-only writes,
> independent Google/MCP grants and signed/runtime/durable-recovery gates. Stage/review,
> run all three gates, commit/push the same PR and record exact local/hosted evidence.
> Stop for review. Do not merge, auto-merge, publish or start package 21.
