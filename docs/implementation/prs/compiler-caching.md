# Compiler caching with full validation

Status: implemented for review on `codex/cache-ci-builds`.
One authorized CI maintenance follow-up after GitHub PR #41, verified merged at
`940d1a03d136f7056f49d85bf9b9daa837979e6a` on 2026-11-03 17:05:52 UTC.
[Coordination](../pr-coordination.md) owns the PR and next action.
[ADR-0046](../../architecture/decisions/0046-compiler-caching.md) owns the decision;
[testing](../../development/testing.md#compiler-caching) owns operation.
Specification [section 21](../../product/master-spec.md#21-cicd-and-release-safety)
requires efficient CI with unchanged security and verification coverage.

| Outcome | Acceptance |
| --- | --- |
| Reusable compilation | Native Xcode compilation cache and allowlisted SDK modules, no cached target products or test results |
| Compatibility | Exact preflight before restore; environment/configuration keys; normal cold behavior on misses |
| Coverage | Every existing validation command, test and required check still runs on hits and misses |
| Cadence | Drafts allocate no runners; ready PRs run full checks; no automatic main-push build |
| Cross-PR reuse | Optional manual full main run seeds GitHub's default-branch cache; branch dispatches skipped |
| Evidence | Strict full local gates; hosted cold/warm timings and counts on the exact same revision, including cache overhead |

No app features, activation, signing, release, protection or billing changes.
Stop at an open reviewed PR; no merge or next work package. Main cache warming
is a documented post-merge maintainer action, not permission to merge.
