# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [progress](progress.md),
[slot 4](prs/private-reminders-slot-4.md),
[ADR-0041](../architecture/decisions/0041-private-sample-lifecycle-recovery.md) and
[native recovery acceptance](../development/private-sample-recovery.md).

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Private Reminders slot 4 — lifecycle and recovery |
| Branch | codex/private-slot4-recovery |
| GitHub PR | [GitHub PR #38](https://github.com/christianzbox/MacHandle/pull/38); exact final-head evidence recorded there |
| Dependency | GitHub PR #37 verified merged; both checks passed on 5e757ccf5b8a510eb67ed655650c7b5affafd0f9; CI 41092336083 |
| Verified squash/base SHA | 69b5445c794f03eeb0d06acd12472aee97031239 |
| Merge time | 2026-10-30 16:56:14 UTC |
| Authorization | One slot 4 PR; account-free, sample data, personal iCloud untouched |
| Writer | Work Mac only; home-Mac setup unverified |
| Next action | Review; stop before merge, live activation or slot 5 |

Implementation checkpoint: `66623334d45f34fa92181e6eac936b4a82c7313e` is pushed.

## Scope and evidence

Native journal inspection, admitted-commit drain, generation-bound callbacks and explicit fresh
session selection/pairing. No automatic replay, reconnect, receipt rewrite or reset. Known outcomes
permit new separately reviewed sample actions; pending/unknown stay blocked and visible. Synthetic
content resets, historical operation evidence does not. The live EventKit writer remains closed.

Focused tests and actual signed same-package crash/relaunch/disconnect/native fresh-session acceptance
passed during implementation. Full staged/final exact-head gates and hosted evidence belong in the
review PR. No EventKit store, TCC request, personal iCloud, paid/employer identity, existing Keychain
items or desktop-client configuration was used. Task-owned jobs/packages/signing keychains removed;
sample UUID/state journals and OS-managed sample containers remain.

## Remaining finish line

Two planned slots remain: 5 actual desktop client, 6 reproducible private installation and test handoff.
Live conflict/isolated permission gates still belong to engineering/maintainer and require separate
authorization/evidence in a verified isolated synthetic-only macOS account. Unknown in-memory effects
cannot be reconciled after the process dies; preserve uncertainty rather than bypassing it. No new PR
count, paid account, personal iCloud access or live readiness claim is introduced.

## Resume on either Mac

Preserve changes and confirm one writer. Fetch, inspect actual GitHub state, then fast-forward this
same branch. Follow [setup](../development/setup.md) for pinned per-process toolchain selection.

```sh
git status --short --branch
git fetch origin --prune
git switch codex/private-slot4-recovery
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Reproduce signed sample recovery and mutation checks when implementation changes; never use a live
provider/TCC procedure to repeat sample validation. Record exact SHA and local/hosted limits in the
same review PR. Push safe checkpoints and stop before merge or slot 5.
