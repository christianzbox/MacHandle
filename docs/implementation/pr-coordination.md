# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [progress](progress.md),
[active brief](prs/local-validation-ready-pr-ci.md) and
[ADR-0044](../architecture/decisions/0044-local-validation-ready-pr-ci.md).

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Full local validation and ready-PR CI |
| Branch | codex/local-validation-ready-pr-ci |
| GitHub PR | To be opened as draft after local validation; final evidence belongs in the PR |
| Dependency | GitHub PR #40 verified merged on 2026-10-30 at 18:46:16 UTC |
| Verified squash/base SHA | 513b8b5aa2ff437ab9f0f6c8cb5dd04c222ad7dc |
| Authorization | One CI scheduling/documentation maintenance PR; retain full coverage |
| Writer | Current Mac only; no concurrent writer |
| Next action | Finish local validation, verify draft skipping, mark ready for full hosted checks, then stop for maintainer review |

## Scope and evidence

Full local checks before final review; draft PR jobs allocate no runners. Ready
PRs run both unchanged full hosted checks; main pushes no longer duplicate them.
Existing ruleset, action pins, read-only token and exact baseline remain intact.
Current local preflight found Xcode 27.2 / Swift 6.4.2 / SDK 27.2 rather than the
pinned 27.1 / 6.4 / 27.0. Supplemental results and strict baseline evidence must
remain separate. No Xcode installation or global selection change is authorized.

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
