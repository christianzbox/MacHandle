# PR coordination and home-Mac handoff

Updated: 2026-11-03, America/Detroit. Read [progress](progress.md),
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
| Authorization | One CI scheduling/documentation maintenance PR; retain full coverage; maintainer selected preinstalled hosted Xcode 27.1 with side-by-side local 27.2 |
| Writer | Current Mac only; no concurrent writer |
| Next action | Review current-revision local/hosted evidence in GitHub PR #41; require both hosted passes before maintainer merge |

## Scope and evidence

Full local checks before final review; draft PR jobs allocate no runners. Ready
PRs run both unchanged full hosted checks; main pushes no longer duplicate them.
Existing ruleset, action pins, read-only token and exact version checks remain intact.
The maintainer selected Xcode 27.1 (27A9275) / Swift 6.4 / SDK 27.0, already
preinstalled on GitHub, with local Xcode 27.2 retained alongside it. This supersedes
the proposed 27.2 pin; see [ADR-0045](../architecture/decisions/0045-xcode-27-2-baseline.md).
Local 27.1 is installed alongside 27.2. Apple archive and application signatures
passed, and strict preflight selected 27.1 with Swift 6.4 and SDK 27.0 automatically.
Global selection is unchanged; no hosted Xcode installation is needed. Final local
and hosted results belong in PR #41; keep draft until all local gates pass.
Earlier 27.2 local results and 27.1 hosted results are historical only.

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
