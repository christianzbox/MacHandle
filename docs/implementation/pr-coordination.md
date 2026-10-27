# PR coordination and home-Mac handoff

Updated: 2026-10-27, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 12 — Synchronization executor (legacy specification ID PR-12) |
| Branch | `codex/synchronization-executor` |
| GitHub PR | Pending creation after staged validation; actual link will be recorded here |
| Dependency | Work package 11, merged in [GitHub PR #12](https://github.com/christianzbox/MacHandle/pull/12) |
| Verified squash/base SHA | `567b5a1a644c4b1ccba10eb21687c8d84d5c82cf` |
| Merge time | 2026-10-27 16:20:09 America/Detroit (20:20:09 UTC), verified before branching |
| Authorization | User authorized package 12 and a review PR on 2026-10-27 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | Finish gates, commit/push and open review; then stop for user review |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Internal SyncExecution coordinates fresh previews, durable pending operations, owned
Google conditional writes, separate result verification and checkpoints. Unknown results
can be verified by reads without replay. The default trusted authority denies execution;
there is no live adapter, external activation factory, app invocation or source writer.

Fifteen new synthetic tests bring totals to 173 Swift + 13 Python tests and fifteen
compiler rejection probes. Staged/final-head local and hosted evidence is recorded in
the review PR. See [ADR-0017](../architecture/decisions/0017-synchronization-executor.md),
[acceptance](prs/pr-12.md#implementation-and-acceptance) and [package 13 brief](prs/pr-13.md).
The [account/setup guide](../development/google-auth-setup.md) remains the maintainer
checklist. No new account/key is needed for the synthetic executor tests.

Packages 13/14/16 own provider time/identity acceptance, whole-process ownership and
prepared-intent recovery, cross-Mac writer transfer and trusted live freshness/privacy/
confirmation/bootstrap adapters. Store/executor reopen tests retain the owned provider
session. No live OAuth, privacy, signed-storage, minimum-OS, home-Mac or release gate
is closed by synthetic integration. No database belongs in Git or developer handoff.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/synchronization-executor
# If already present: git switch codex/synchronization-executor
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's actual GitHub PR/reviews/checks before editing. If merged, verify
the squash SHA and wait for new direction. Record merge bookkeeping in the next
explicitly authorized PR, never directly on main.

## Copyable next-session prompt

> Continue MacHandle work package 12 on codex/synchronization-executor and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0017 and acceptance/setup gates.
> Prerequisite GitHub PR #12 merged at 567b5a1a644c4b1ccba10eb21687c8d84d5c82cf.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. No live setup, trusted activation or end-to-end sync is implied.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 13.
