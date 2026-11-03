## Problem and result

Describe the focused roadmap item and actual implemented behavior.

## Scope and dependencies

Roadmap PR ID, prerequisite merged PRs, and deliberate exclusions.

## Validation

Commands, toolchain, tested commit, pass/fail/skip results. Distinguish local checks,
hosted CI, and live behavior. Do not attach sensitive logs.

Keep this PR draft during implementation. Run all three local gates before the
final review push, then mark ready for review to run the full hosted checks.
Record any local baseline blocker separately from supplemental checks. Convert
back to draft before further checkpoint pushes; require actual successful
`Build and test` and `Secret scan` results on the current revision before merge.

## Security and privacy

Permission/data-flow changes, synthetic fixtures, manual diff review, and scanner
results. Identify risks and unverified assumptions.

## Handoff

Updated progress, coordination, roadmap, active brief and affected docs/ADRs. Leave this PR
open for maintainer review; do not auto-merge or publish. For a machine handoff,
record the existing branch, pushed SHA, remaining work, and exact next action in
docs/implementation/pr-coordination.md, with scoped evidence in progress.md, so a
fresh session can resume without earlier conversations. Record actual merge evidence
in the next authorized PR after the maintainer merges; never mark this open PR merged.
