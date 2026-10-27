# PR coordination and home-Mac handoff

Updated: 2026-10-27, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 11 — Pure reconciliation planner (legacy specification ID PR-11) |
| Branch | `codex/reconciliation-planner` |
| GitHub PR | Pending creation after staged validation; actual link will be recorded here |
| Dependency | Work package 10, merged in [GitHub PR #11](https://github.com/christianzbox/MacHandle/pull/11) |
| Verified squash/base SHA | `4a5ad09a22be45b681c46675d756500603a58d8c` |
| Merge time | 2026-10-27 16:05:30 America/Detroit (20:05:30 UTC), verified before branching |
| Authorization | User authorized package 11 and a review PR on 2026-10-27 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | Finish gates, commit/push and open review; then stop for user review |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

SyncPlanning compares explicit snapshots, mappings and field policy to propose create,
update, delete, no-change, conflict or manual intervention. Availability clears details;
unknown/partial/stale evidence blocks work. Every delete requires confirmation and
bounded absence alone cannot authorize deletion. Proposals confer no provider authority.
The app links but never invokes the planner. No executor, provider/storage integration,
source write, database startup, account setup or live sync is added.

Eighteen synthetic planner tests bring totals to 158 Swift + 13 Python tests and thirteen
compiler rejection probes. Staged/final-head local and hosted evidence is recorded in
the review PR. See [ADR-0016](../architecture/decisions/0016-pure-reconciliation-planner.md),
[acceptance](prs/pr-11.md#implementation-and-acceptance) and [package 12 brief](prs/pr-12.md).
The [account/setup guide](../development/google-auth-setup.md) remains the maintainer
checklist; no new developer account or key is needed for this pure package.

Packages 12–14 own trusted adapter integration, freshness/absence evidence, remote
identity/outcome verification, durable IDs, canonical time conversion and writer transfer.
Do not relabel local-cache snapshots or persisted checkpoints as complete fresh provider
state. Signed privacy/OAuth/minimum-OS/home-Mac and release gates remain open.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/reconciliation-planner
# If already present: git switch codex/reconciliation-planner
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

> Continue MacHandle work package 11 on codex/reconciliation-planner and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0016 and acceptance/setup gates.
> Prerequisite GitHub PR #11 merged at 4a5ad09a22be45b681c46675d756500603a58d8c.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. No live setup, execution authority or sync acceptance is implied.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 12.
