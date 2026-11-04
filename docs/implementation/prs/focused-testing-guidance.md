# Focused testing and synthetic visual-review guidance

Status: implemented for review in [GitHub PR #43](https://github.com/christianzbox/MacHandle/pull/43)
on `codex/focused-testing-guidance`; see
[coordination](../pr-coordination.md) for the review handoff.
Authorized 2026-11-04 after GitHub PR #42 merged at
`e48d6d403a745608706e2f36bbbda32b26138c88` and its manual main cache warm-up passed.

## Scope and decision

Clarify fast focused checks during editing and brief synthetic visual review for
visible changes. Retain all three final local gates and both full hosted checks.
Keep durable tests tied to distinct behavior/security contracts; temporary
investigations require passing results and retained regression protection before
cleanup. Record material runtime growth rather than removing tests by count.
Update completed caching/handoff facts using GitHub evidence.

The alternative of reduced final coverage is rejected: current tests protect
permission, approval/replay, privacy and recovery boundaries, while compilation
accounts for most hosted time. An exhaustive UI matrix after every edit adds cost
without proportional evidence; review representative affected native screens.
Documentation-only changes need no UI review. Live providers and personal accounts
remain outside synthetic review authorization. This elaborates the development
cadence in [ADR-0044](../../architecture/decisions/0044-local-validation-ready-pr-ci.md)
without changing architecture, scripts or workflow behavior; no new ADR is needed.

## Acceptance and evidence

- AGENTS and [testing](../../development/testing.md) give focused command examples,
  require an actually executed nonempty selection, and preserve every final gate.
- Visible changes receive scoped synthetic review and record revision/screens,
  sizes/settings/results/limits; no extra hosted job or full matrix is required.
- GitHub PR #42 merge and the successful main warm-up replace stale pending claims.
- Review the diff to prove no app, test, script, toolchain, workflow or protection
  changes. Execute the focused examples, documentation-link checks and all three
  full local gates; record exact final-head results in the PR before ready review.
- Require both current-revision hosted checks before claiming merge readiness.

Timing instrumentation is not part of this PR. Engineering may propose it later
if phase-level measurements are needed for a demonstrated iteration bottleneck.
No merge, deployment, release, new product work package or website change is included.
