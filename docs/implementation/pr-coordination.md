# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 14 — Deletion safety and recovery (legacy specification ID PR-14) |
| Branch | codex/deletion-safety-recovery |
| GitHub PR | [GitHub PR #15 — Add deletion safeguards and verified synchronization recovery](https://github.com/christianzbox/MacHandle/pull/15), open for review |
| Dependency | Work package 13, merged in [GitHub PR #14](https://github.com/christianzbox/MacHandle/pull/14) |
| Verified squash/base SHA | 554c4f2cc7914ae4b963f30b28cb529c94f1d3fe |
| Merge time | 2026-10-28 09:35:11 America/Detroit (13:35:11 UTC), verified before branching |
| Authorization | User authorized package 14 and a review PR on 2026-10-28 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | User review of GitHub PR #15; do not merge or start package 15 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Exact destructive batch approval supplements individual authority. Internal recovery can
restore authenticated standby capabilities, verify original IDs after uncertain outcomes,
restore retained metadata into empty stores, rebind verified source/legacy baselines and
conditionally transfer the cooperative writer. It never infers authority from a title or
marker, blindly replays unknown writes or silently recreates events.

Twenty-one new tests bring totals to 211 Swift + 13 Python and sixteen compiler probes.
Implementation checkpoint `32e2abb6a0f19d62a181e5f64eafca77966a8050` passed all
three staged gates (environment 1.05s, validation 61.42s, secret scan 1.84s). Exact final
pushed-head local checks and separate hosted evidence are recorded in [GitHub PR #15 — Add deletion safeguards and verified synchronization recovery](https://github.com/christianzbox/MacHandle/pull/15).
See [ADR-0019](../architecture/decisions/0019-deletion-safety-recovery.md),
[acceptance](prs/pr-14.md#implementation-and-acceptance),
[recovery procedure](../development/sync-recovery.md) and [package 15 brief](prs/pr-15.md).
The [account/setup guide](../development/google-auth-setup.md) remains the maintainer
checklist. No new account/key is needed for the synthetic tests.

No live sync, original-calendar mutation or database transfer is authorized. Trusted
account/source continuity, UI/backup acquisition, canonical installation composition,
signed privacy, actual Google conditional requests and two-Mac acceptance remain gates
before package 16 activation. Missing evidence and unavailable old writers require
intervention; this protocol has no timed lease or forced takeover. Legacy destinations
remain standby until a controlled migration is designed. Package 15 owns scheduling.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/deletion-safety-recovery
# If already present: git switch codex/deletion-safety-recovery
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

> Continue MacHandle work package 14 on codex/deletion-safety-recovery and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0019 and acceptance/setup gates.
> Prerequisite GitHub PR #14 merged at 554c4f2cc7914ae4b963f30b28cb529c94f1d3fe.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. Never infer identity from content or replay unknown mutations.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 15.
