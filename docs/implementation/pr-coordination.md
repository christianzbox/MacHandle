# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 15 — Background synchronization (legacy specification ID PR-15) |
| Branch | codex/background-synchronization |
| GitHub PR | Pending creation after staged validation |
| Dependency | Work package 14, merged in [GitHub PR #15](https://github.com/christianzbox/MacHandle/pull/15) |
| Verified squash/base SHA | 69a23b9c7a96b8ffc562400a4b9db7642eaf55d2 |
| Merge time | 2026-10-28 11:11:25 America/Detroit (15:11:25 UTC), verified before branching |
| Authorization | User authorized package 15 and a review PR on 2026-10-28 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | Finish checks and open review PR; stop before merge or package 16 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

The internal coordinator owns one timer and one worker, debounces source changes and drains
canceled jobs before replacement/transfer. Scheduled execution uses fresh trusted input and
all existing approval/recovery checks. Native lifecycle adapters provide scheduling hints;
Settings offers explicit launch at login without enabling any external connection.

Twenty added tests bring totals to 231 Swift + 13 Python and seventeen compiler probes.
Staged/final-head local checks and separate hosted results will be recorded in the review PR.
See [ADR-0020](../architecture/decisions/0020-background-synchronization.md),
[acceptance](prs/pr-15.md#implementation-and-acceptance),
[testing](../development/testing.md#work-package-15-background-coverage) and [package 16 brief](prs/pr-16.md).
The [account/setup guide](../development/google-auth-setup.md) distinguishes personal testing
from release enrollment and Apple/Google review. No new account/key is needed for tests.

No live sync, source-calendar mutation, login registration or system setting change was
performed. Signed login/wake/network/Keychain, whole-app energy, minimum OS and two-Mac
behavior remain unverified. Package 16 owns trusted live composition and onboarding;
source-change/network signals never confer permission. User is not preparing a release.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/background-synchronization
# If already present: git switch codex/background-synchronization
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

> Continue MacHandle work package 15 on codex/background-synchronization and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0020 and acceptance/setup gates.
> Prerequisite GitHub PR #15 merged at 69a23b9c7a96b8ffc562400a4b9db7642eaf55d2.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. Never infer identity from content or replay unknown mutations.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 16.
