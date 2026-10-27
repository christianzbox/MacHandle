# PR coordination and home-Mac handoff

Updated: 2026-10-27, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 13 — Recurrence, all-day and timezone correctness (legacy specification ID PR-13) |
| Branch | codex/recurrence-time-correctness |
| GitHub PR | Pending creation after staged validation |
| Dependency | Work package 12, merged in [GitHub PR #13](https://github.com/christianzbox/MacHandle/pull/13) |
| Verified squash/base SHA | 1d265050f0e12aa21847b26875e32e12c0d13f4b |
| Merge time | 2026-10-27 16:50:32 America/Detroit (20:50:32 UTC), verified before branching |
| Authorization | User authorized package 13 and a review PR on 2026-10-27 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | Complete gates, push and open one review PR; stop for user review |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Bounded occurrence normalization rejects ambiguous anchors; planning adds local-day
horizons and content-v2 fingerprints; Google wire encoding retains exactly round-tripping
whole/millisecond timestamps. Synthetic normalization/planner/store/executor tests cover
moved/cancelled instances, DST/all-day travel, stable IDs and horizon convergence.

Seventeen new tests bring totals to 190 Swift + 13 Python tests and fifteen compiler
rejection probes. All Swift tests passed during implementation; full staged and final-head
gates and hosted outcomes remain separate evidence. See [ADR-0018](../architecture/decisions/0018-recurrence-time-correctness.md),
[acceptance](prs/pr-13.md#implementation-and-acceptance) and [package 14 brief](prs/pr-14.md).
The [account/setup guide](../development/google-auth-setup.md) remains the maintainer
checklist. No new account/key is needed for these synthetic tests.

Content-v1 baselines deliberately conflict; no automatic migration or replacement insert.
Package 14 owns verified legacy recovery, calendar/account identity migration, destination
reconstruction and writer transfer. Package 16 owns trusted live composition, freshness,
privacy, confirmation and bootstrap. Synthetic tests do not prove actual EventKit rule
expansion, Google precision acceptance, signed storage, minimum OS or home-Mac behavior.
No live activation, original-calendar mutation or database transfer is authorized.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/recurrence-time-correctness
# If already present: git switch codex/recurrence-time-correctness
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

> Continue MacHandle work package 13 on codex/recurrence-time-correctness and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0018 and acceptance/setup gates.
> Prerequisite GitHub PR #13 merged at 1d265050f0e12aa21847b26875e32e12c0d13f4b.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. Do not silently rebaseline legacy hashes or infer identity from content.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 14.
