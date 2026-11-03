# PR coordination and home-Mac handoff

Updated: 2026-11-03, America/Detroit. Read [progress](progress.md),
[active brief](prs/compiler-caching.md) and
[ADR-0046](../architecture/decisions/0046-compiler-caching.md).

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Compiler caching with full validation |
| Branch | codex/cache-ci-builds |
| GitHub PR | Draft caching PR to be opened; exact-revision evidence belongs there |
| Dependency | GitHub PR #41 verified merged on 2026-11-03 at 17:05:52 UTC |
| Verified squash/base SHA | 940d1a03d136f7056f49d85bf9b9daa837979e6a |
| Authorization | One compiler-caching maintenance PR; retain full local and hosted coverage |
| Writer | Current Mac only; no concurrent writer |
| Next action | Execute all final local gates, then measure full hosted cold and warm runs on the same final revision; stop for review |

## Scope and evidence

Native Xcode compilation caching and allowlisted SDK modules only; full test and
build commands remain mandatory regardless of cache hit. Exact toolchain and
image/configuration namespaces prevent incompatible reuse. Source checkout,
target graph and test execution remain fresh. No credentials, archived Xcode,
private fixtures, target products, build databases or test results are restored.
Draft jobs still allocate no runners. Manual main-only execution can seed a
shared cache after merge; no automatic post-merge or scheduled run is added.

The current Mac has Xcode 27.1 (27A9275), Swift 6.4 and SDK 27.0 alongside 27.2.
Global selection is unchanged. PR #41 passed strict local checks and both hosted
checks, with an 8m 44s macOS job. Those results are historical baseline evidence;
final caching-PR results and timings belong on its current revision. Default-branch
cache warming is not yet performed and does not authorize merge.

## Resume on either Mac

Preserve changes and confirm one writer. Fetch and fast-forward this branch.
Follow [setup](../development/setup.md) and [testing](../development/testing.md).

```sh
git status --short --branch
git fetch origin --prune
git switch codex/cache-ci-builds
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Record exact local and hosted evidence separately. Require both full hosted
checks on the current revision before maintainer merge. Stop with this PR open;
no auto-merge, release, personal-data activation or next product work package.
