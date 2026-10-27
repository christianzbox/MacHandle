# PR coordination and home-Mac handoff

Updated: 2026-10-27, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 10 — SQLite persistence (legacy specification ID PR-10) |
| Branch | `codex/sqlite-persistence` |
| GitHub PR | [GitHub PR #11 — Add versioned SQLite sync persistence](https://github.com/christianzbox/MacHandle/pull/11), open for review |
| Dependency | Work package 09, merged in [GitHub PR #10](https://github.com/christianzbox/MacHandle/pull/10) |
| Verified squash/base SHA | `928732effe0985ed34a386cba4367ffd69bdc43c` |
| Merge time | 2026-10-27 15:29:13 America/Detroit (19:29:13 UTC), verified before branching |
| Authorization | User authorized package 10 and a review PR on 2026-10-27 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | User review of GitHub PR #11; do not merge or start package 11 |

**Work-package numbers are not GitHub PR numbers.** Use the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs) and descriptive titles.
Legacy specification IDs, brief paths and anchors remain stable.

## Scope, evidence and limits

SyncPersistence implements SDK SQLite migrations, bound resource/event metadata,
fingerprints, unknown-operation recovery records, tombstones and revision checkpoints.
Private local files and an advisory lock support one cooperating local store writer;
restored values always require remote verification. The app links but never opens it.
There is no provider integration, database startup, planner/executor, source write,
MCP, cloud database or account setup. No secrets or event bodies enter persistence.

Implementation checkpoint `2c2961ab56a6bc58fa0391b3cc92f626f90641d9` passed all three
standard gates: 140 Swift + 13 Python tests, twelve compiler rejection probes, universal
builds/analyze, formatting and history/index scans. Final handoff-head local/hosted
evidence is recorded separately in [GitHub PR #11](https://github.com/christianzbox/MacHandle/pull/11). See [ADR-0015](../architecture/decisions/0015-sqlite-persistence.md),
[acceptance](prs/pr-10.md#implementation-and-acceptance), the
[account/local setup guide](../development/google-auth-setup.md) and
[package 11 brief](prs/pr-11.md).

Integration/recovery owners: packages 12/14 after authorization, including actual
account binding, remote identity/outcome verification, durable IDs in the Google client,
backup/retention and cross-Mac writer transfer. A local file lock and persisted marker
are not provider authority. Live privacy/OAuth/signed-storage/minimum-OS/home-Mac and
release gates remain open. No database file should travel in Git or developer handoff.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the
other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/sqlite-persistence
# If already present: git switch codex/sqlite-persistence
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

> Continue MacHandle work package 10 on codex/sqlite-persistence and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0015 and acceptance/setup gates.
> Prerequisite GitHub PR #10 merged at 928732effe0985ed34a386cba4367ffd69bdc43c.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. No live setup, privacy acceptance, provider recovery authority or sync is implied.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 11.
