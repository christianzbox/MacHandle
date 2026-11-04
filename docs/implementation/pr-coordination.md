# PR coordination and home-Mac handoff

Updated: 2026-11-04, America/Detroit. Read [progress](progress.md),
[active brief](prs/focused-testing-guidance.md), and [testing](../development/testing.md).

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Focused testing and synthetic visual-review guidance |
| Branch | codex/focused-testing-guidance |
| GitHub PR | [GitHub PR #43](https://github.com/christianzbox/MacHandle/pull/43); exact-revision validation and current review status recorded there |
| Dependency | GitHub PR #42 verified merged on 2026-11-03 at 17:47:14 UTC |
| Verified squash/base SHA | e48d6d403a745608706e2f36bbbda32b26138c88 |
| Authorization | One documentation-only PR; preserve every full local/hosted gate; leave shumylo-website alone |
| Writer | Current Mac only; no concurrent writer |
| Next action | Validate final documented commands and full local gates, push, mark ready, then stop for maintainer review |

## Scope and evidence

Document focused checks while editing and proportional synthetic native UI review
for visible changes, with durable regression and runtime discipline. No app, tests,
validation scripts, workflow, toolchain or protection changes. Final exact-revision
commands/results belong in the review PR; focused checks are not a full-gate pass.
Synthetic UI evidence never substitutes for live provider, sandbox or device gates.

GitHub PR #42 completed with full local and hosted cold/warm validation. Its
[authorized main cache warm-up](https://github.com/christianzbox/MacHandle/actions/runs/41687675936)
also passed on the merge SHA above on 2026-11-03. This is completed work, not a new
instruction to warm caches or repeat those timing experiments. Compiler caches
remain optional acceleration; all tests still execute. See the
[completed brief](prs/compiler-caching.md) and
[ADR-0046](../architecture/decisions/0046-compiler-caching.md).

## Resume on either Mac

Preserve changes and confirm one writer. Fetch and fast-forward the active branch;
follow [setup](../development/setup.md). Keep the PR draft during checkpoints.

```sh
git status --short --branch
git fetch origin --prune
git switch codex/focused-testing-guidance
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Record local and hosted results separately. Require both full hosted checks on
the current revision before maintainer merge. Stop with the PR open; no auto-merge,
release, personal-data activation or next product work package. Do not change any
existing path-bound private installation or the other Mac's setup for this task.
