# PR coordination and home-Mac handoff

Updated: 2026-10-26, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not a chat, stash or local cache.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 07 — Calendar Reading and Availability (legacy specification ID PR-07) |
| Branch | `codex/calendar-reads-availability` |
| GitHub PR | [GitHub PR #8 — Add bounded Calendar reads and availability](https://github.com/christianzbox/MacHandle/pull/8), open for review |
| Dependency | Work package 06, merged in [GitHub PR #7](https://github.com/christianzbox/MacHandle/pull/7) |
| Verified squash/base SHA | `ab345134daa94f4a4a195ae709e94d6f3d29c7e2` |
| Merge time | 2026-10-26 15:58:42 America/Detroit (19:58:42 UTC), verified before branching |
| Authorization | User authorized this package and a review PR on 2026-10-26 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | `cff1c647f89575b7ad0f72626793c39a41d353f3` |
| Next action | User review of GitHub PR #8; final exact-head local/hosted evidence in its description |

**Work-package numbers are not GitHub PR numbers.** Use the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs) and descriptive titles.
Legacy specification IDs, brief paths and anchors remain stable.

## Scope, evidence and limits

Selected bounded Calendar reads now normalize occurrences and project conservative
availability. Native Read defaults to availability; title/detail modes require explicit
selection. A private real policy authority is separate from sample previews. Current
OS authorization, selection and field/operation grants govern reads; changes invalidate
pending/displayed results. Data remains in memory, with no source writes or exports.
[ADR-0012](../architecture/decisions/0012-calendar-reads-availability.md) and the
[acceptance map](prs/pr-07.md#implementation-and-acceptance) record decisions and tests.
[Work package 08](prs/pr-08.md) remains a planned brief only.

Focused evidence: 84 Swift tests passed. A disposable synthetic native harness verified
availability/title/detail projections, mode-change and explicit clearing, disable,
partial-coverage messaging and scroll layout. No real prompt/calendar data was accessed.
The staged tree committed as `cff1c647f89575b7ad0f72626793c39a41d353f3` passed
strict preflight (0.24s), full validation (24.31s: 84 Swift + 13 Python tests,
zero failures/skips, builds/analyze, eight compiler probes, format/privacy/whitespace),
and pinned history/index secret scans (1.49s; no detected leaks). 544 local documentation
links/anchors/case checks passed; all 31 packages/legacy anchors retained. The final
handoff-only commit receives fresh gates; exact head/local/hosted evidence is on PR #8.

Live TCC grant/deny/revoke, sandbox reads and real recurrence expansion remain unverified
pending an explicitly authorized isolated Calendar account/device (maintainer/provider
work, before milestone A acceptance; revisit package 13). Home-Mac/oldest-OS/Intel and
release signing remain separate gates. No event writes, external connections,
credentials, persistence, login registration or sync. Specification/LICENSE/toolchain
and repository protections are preserved. Calendar entitlement is unchanged; its
usage description now explains explicitly requested local event reads.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the
other Mac stopped writing before resuming. Then:

```sh
git status --short --branch
git fetch origin --prune
# First checkout on this Mac:
git switch --track origin/codex/calendar-reads-availability
# If already present: git switch codex/calendar-reads-availability
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's current GitHub PR head/reviews/checks before edits. If merged,
verify the actual squash SHA and stop for direction. No bookkeeping push to main or
automatic next package. Do not resume the merged Calendar discovery branch.

## Copyable next-session prompt

> Continue MacHandle work package 07, Calendar reads/availability, on
> codex/calendar-reads-availability and the GitHub PR linked above. Read AGENTS,
> coordination/progress, ADR-0012 and the acceptance map. Predecessor GitHub PR #7
> merged at ab345134daa94f4a4a195ae709e94d6f3d29c7e2. Preserve changes, fetch/fast-forward
> and confirm one writer. Address requested review feedback or authorized isolated
> device checks only. Never access real calendars merely to validate the build.
> Stage/review, run the three standard gates, commit/push the same PR and record exact
> evidence. Stop for user review; do not merge, auto-merge, publish or start package 08.
