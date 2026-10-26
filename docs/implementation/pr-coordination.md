# PR coordination and home-Mac handoff

Updated: 2026-10-26, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not a chat, stash or local cache.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 06 — Calendar Authorization and Discovery (legacy specification ID PR-06) |
| Branch | `codex/calendar-authorization-discovery` |
| GitHub PR | Pending creation; never infer its number from the work package |
| Dependency | Work package 05, merged in [GitHub PR #6](https://github.com/christianzbox/MacHandle/pull/6) |
| Verified squash/base SHA | `12b4ebf80816dcd307673a64085d00f88bb20981` |
| Merge time | 2026-10-26 15:18:26 America/Detroit (19:18:26 UTC), verified before branching |
| Authorization | User authorized this package and a review PR on 2026-10-26 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending staged validation/commit |
| Next action | Finish standard checks, push/open review PR and stop |

**Work-package numbers are not GitHub PR numbers.** Use the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs) and descriptive titles.
Legacy specification IDs, brief paths and anchors remain stable.

## Scope, evidence and limits

Calendar-only EventKit metadata discovery now has explicit opt-in, source identities,
empty-by-default selection, denied/incomplete/unavailable handling and asynchronous
invalidation. Startup and lifecycle refresh never prompt; disable clears names and
selections without claiming to revoke the OS grant. Names/choices remain in memory.
Real discovery is separate from synthetic policy actors and cannot enable Google/MCP.
[ADR-0011](../architecture/decisions/0011-calendar-authorization-discovery.md) and the
[acceptance map](prs/pr-06.md#implementation-and-acceptance) record decisions and tests.
[Work package 07](prs/pr-07.md) remains a planned brief only.

Focused evidence: 65 Swift tests passed. Default locally signed universal Debug launch
and off-state Cmd-5 UI were inspected. The built full-access usage description and
Calendar entitlement were checked. A disposable synthetic native harness verified
selection/count, disable clearing and denied/incomplete/unavailable/empty states;
its observation fix has a regression test. No real prompt/calendar metadata was accessed.
The final staged/final-head standard gates and hosted result are recorded separately.

Live TCC grant/deny/revoke and sandbox discovery remain unverified pending an explicitly
authorized isolated Calendar account/device (maintainer/provider work, package 06/07).
Home-Mac/oldest-OS/Intel and release signing remain separate gates. No event reads,
writes, external connections, credentials, persistence, login registration or sync.
Specification/LICENSE/toolchain/repository protections are preserved. Calendar-only
entitlement/usage description are deliberate additions; no other permission scope.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the
other Mac stopped writing before resuming. Then:

```sh
git status --short --branch
git fetch origin --prune
# First checkout on this Mac:
git switch --track origin/codex/calendar-authorization-discovery
# If already present: git switch codex/calendar-authorization-discovery
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's current GitHub PR head/reviews/checks before edits. If merged,
verify the actual squash SHA and stop for direction. No bookkeeping push to main or
automatic next package. Do not resume the merged native-foundation branch.

## Copyable next-session prompt

> Continue MacHandle work package 06, Calendar authorization/discovery, on
> codex/calendar-authorization-discovery and the GitHub PR linked above. Read AGENTS,
> coordination/progress, ADR-0011 and the acceptance map. Predecessor GitHub PR #6
> merged at 12b4ebf80816dcd307673a64085d00f88bb20981. Preserve changes, fetch/fast-forward
> and confirm one writer. Address requested review feedback or authorized isolated
> device checks only. Never access real calendars merely to validate the build.
> Stage/review, run the three standard gates, commit/push the same PR and record exact
> evidence. Stop for user review; do not merge, auto-merge, publish or start package 07.
