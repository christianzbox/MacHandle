# ADR-0044: Full local validation and ready-PR CI

Date: 2026-10-30. Status: implemented for review.

## Context

The maintainer requested fewer hosted Actions runs while retaining the existing
coverage. The workflow previously ran every PR update and every push to main,
including documentation/checkpoint updates and the post-merge squash. The local
scripts already execute the same maintained tests as CI. This is a focused
maintenance follow-up after GitHub PR #40, not another private Reminders slot.
[Specification §21](../../product/master-spec.md#21-cicd-and-release-safety)
requires efficient CI, stable required checks, least privilege and synthetic data.

## Decision

Use draft PRs for implementation and checkpoints. Run the full local environment,
validation and secret-scan gates before the final review push. Mark ready for
review only when implementation is ready for final hosted verification. Both
existing hosted jobs still run their complete unchanged scripts on opened,
synchronize, reopened and ready_for_review events when the PR is not draft.

Draft events skip both jobs before runner allocation, using distinct `(draft)`
names so a skipped job cannot publish success under a required-check name.
The converted_to_draft event shares the existing per-PR concurrency group to
cancel older work. Ready PR updates always rerun checks for changed code. No
path filters, label authorization, manual replacement statuses, self-hosted
runner, new credentials or privileged pull_request_target event are introduced.

Remove push-to-main CI. Preserve the active strict up-to-date main ruleset and
its GitHub Actions checks, `Build and test` and `Secret scan`. The full PR merge
checkout is the integration gate; the final squash SHA has no separate rerun.
A ready event must actually complete both checks successfully before merge.
Draft records are not verification. No workflow/job or ruleset check is reduced
to a smoke test or replaced by a claimed local result.

## Alternatives and consequences

- Full hosted CI on every draft checkpoint plus every merge repeats expensive
  native builds. Retaining it conflicts with the requested execution policy.
- Local-only tests or a reduced hosted suite would lose independent full-suite
  coverage. Keep all tests in the final hosted gate instead.
- Manual workflow_dispatch alone does not provide the same PR event/check
  semantics. Draft-to-ready integrates with GitHub's ordinary review workflow.
- A self-hosted runner adds machine availability and untrusted-code isolation
  responsibilities. It is unnecessary for this scheduling change.
- Draft workflows can appear as skipped records, but no runners execute. A ready
  PR still spends compute on subsequent pushes; return it to draft before a new
  iteration. Canceling cannot recover time already consumed.
- Exact local parity still needs the pinned Xcode/Swift/SDK. A newer-toolchain
  compatibility pass is supplemental, not permission to weaken the baseline.

## Verification and limits

The unchanged shared scripts preserve maintained coverage. Verify the event/draft
matrix, job names, commands, read-only token, immutable actions and concurrency;
then observe a draft PR allocating no runners and its ready transition running
both full jobs. Final snapshot/results belong in the review PR and
[progress](../../implementation/progress.md). Hosted scheduling acceptance does
not prove live providers or account billing savings. This decision changes the
execution cadence described in [ADR-0002](0002-portable-development.md), not its
pinned toolchain or clean-checkout requirements.

References: [GitHub PR events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request),
[draft PR stages](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/changing-the-stage-of-a-pull-request),
[required and skipped checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
