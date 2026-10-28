# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 21 — authorized Calendar mutations (legacy specification ID PR-21) |
| Branch | codex/authorized-calendar-mutations |
| GitHub PR | Pending creation after staged validation |
| Dependency | Work package 20, merged in [GitHub PR #21](https://github.com/christianzbox/MacHandle/pull/21) |
| Verified squash/base SHA | 5dda18451154e0a72b2ecb47df851c8ebb4a306b |
| Merge time | 2026-10-28 15:57:47 America/Detroit (19:57:47 UTC), verified before branching |
| Authorization | User authorized work package 21 after GitHub PR #21 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending staged gates and commit; exact final SHA will be recorded in the PR |
| Next action | Validate and open this review PR; stop before merge or package 22 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Gated internal EventKit create/update/delete adapter, current authority after durable preparation,
exact standalone target/snapshot checks, separate private SQLite intent/receipt journal and restart
containment. Unknown/pending blocks subsequent writes; no retry, reset or automatic resolution.
EventKit has no atomic CAS and can recreate a concurrently deleted item. The live factory always
denies; native sample review, MCP read grants and Google's source-read-only access stay unchanged.

Sixteen new focused tests passed against synthetic backends and private temporary SQLite stores.
Target totals are 335 Swift + 23 Python checks and 33 negative compiler probes. Full staged gates,
exact pushed checkpoint and independent hosted results will be recorded in progress/PR. See
[ADR-0026](../architecture/decisions/0026-calendar-mutation-journal.md),
[acceptance](prs/pr-21.md#implementation-and-acceptance) and
[developer checks](../development/calendar-mutations.md).

Engineering/maintainer retain approved identity, signed broker/current OS/native grant/review/outcome
wiring, scoped candidate reads, recovery/retention and isolated conflict/recurrence/time acceptance
before real writes. No real account/content, credential, permission or installed client configuration
was used. Reminders [package 22](prs/pr-22.md) is preparation only; Notes remains experimental.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/authorized-calendar-mutations
# If already present: git switch codex/authorized-calendar-mutations
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

> Continue MacHandle work package 21 on codex/authorized-calendar-mutations and its linked PR.
> Read AGENTS, coordination/progress, ADR-0026 and the acceptance ledger. Prerequisite
> GitHub PR #21 merged at 5dda18451154e0a72b2ecb47df851c8ebb4a306b. Preserve changes, fetch/fast-forward
> and confirm one writer. Address requested review feedback only. Keep the live writer factory
> closed and pending/unknown durable recovery blocked. Retain signed/native and provider conflict
> acceptance gates. Stage/review, run all three gates, commit/push the same PR and record exact
> local/hosted evidence. Stop for review. Do not merge, auto-merge, publish or start package 22.
