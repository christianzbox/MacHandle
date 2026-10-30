# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [progress](progress.md),
[active brief](prs/local-validation-ready-pr-ci.md) and
[ADR-0044](../architecture/decisions/0044-local-validation-ready-pr-ci.md).

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Full local validation and ready-PR CI |
| Branch | codex/local-validation-ready-pr-ci |
| GitHub PR | [GitHub PR #41](https://github.com/christianzbox/MacHandle/pull/41); exact-head local/hosted evidence recorded there |
| Dependency | GitHub PR #40 verified merged on 2026-10-30 at 18:46:16 UTC |
| Verified squash/base SHA | 513b8b5aa2ff437ab9f0f6c8cb5dd04c222ad7dc |
| Authorization | One CI scheduling/documentation maintenance PR; retain full coverage; maintainer additionally requested exact Xcode 27.2 upgrade |
| Writer | Current Mac only; no concurrent writer |
| Next action | Keep GitHub PR #41 draft until hosted xcode-27 includes 27B52; then run both full checks and stop for maintainer review |

## Scope and evidence

Full local checks before final review; draft PR jobs allocate no runners. Ready
PRs run both unchanged full hosted checks; main pushes no longer duplicate them.
Existing ruleset, action pins, read-only token and exact version checks remain intact.
The maintainer explicitly requested the shared Xcode 27.2 (27B52) / Swift 6.4.2 /
SDK 27.2 baseline; see [ADR-0045](../architecture/decisions/0045-xcode-27-2-baseline.md).
The current Mac has that tuple. No installation or global selection change is
needed. Strict local results belong in PR #41. The hosted inventory still has
27.2 RC 27B48, so hosted parity is pending, and the PR stays draft to avoid known
failing Actions runs. Engineering owns rechecking on a runner image update.
Earlier supplemental results and successful 27.1 CI are historical only.

## Resume on either Mac

Preserve changes and confirm one writer. Fetch, inspect actual PR state and
fast-forward this branch. Follow [setup](../development/setup.md) for per-process
toolchain selection and [testing](../development/testing.md) for draft/ready flow.

```sh
git status --short --branch
git fetch origin --prune
git switch codex/local-validation-ready-pr-ci
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

GitHub PR #40 completed the six-slot sample Reminders engineering handoff.
[Maintainer hands-on acceptance](../development/private-testing-handoff.md) and
live provider/conflict gates remain open. This maintenance PR does not authorize
another product phase, personal-data activation, merge or public release.
