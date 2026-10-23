# PR coordination and session handoff

Updated: 2026-10-23. This file owns active work/branch/PR state and next action.
[Progress](progress.md) owns implementation and verification evidence; the
[master plan](../../plans/MacHandleMasterImplementationPlan.md) and [roadmap](pr-roadmap.md)
own execution scope. Use GitHub to refresh these dated facts before acting.

## Active work

| Field | Current value |
| --- | --- |
| Work package | PR-01 — Repository Foundation and Security, including work/home workflow and canonical documentation additions |
| Branch | `codex/pr-01-repository-foundation` |
| Existing PR | [GitHub #1](https://github.com/christianzbox/MacHandle/pull/1), targeting `main`; open, not merged, no auto-merge |
| Review/merge owner | Maintainer/user; agents leave the PR open |
| Last fully verified checkpoint recorded in Git | `425ca3c0c09a20fe14e283a0a9671f829f7ea7a4`; see progress for scoped evidence |
| Current increment | Review original/additional requirements, fix preflight Python ordering, clarify test entry points and decision rationale, refresh evidence on this existing PR |
| Prior dependency | Existing main initialization `2429cc29212993e95c6ed09c47db52aa2d6f2fd5`; no prerequisite implementation PR |
| Merge SHA | None; do not infer merge from green checks or a preview merge ref |
| Next eligible package | PR-02 only after GitHub confirms PR-01 merged; no PR-02 implementation has begun |

The checkpoint is historical evidence, not a fixed expected latest head. Read the
current PR head/CI/comments and compare your local SHA each time. Documentation
commits after that checkpoint have their own validation recorded on the PR.

## Resume on either Mac

1. Inspect the worktree; preserve local changes and unpushed commits. Fetch origin.
   Follow [the setup/handoff guide](../development/setup.md) for first checkout or
   fast-forward resume, authentication, pinned Xcode and branch divergence.
2. Inspect the existing PR state, head, comments and checks. Useful read commands:

   ```sh
   git status --short --branch
   git fetch origin --prune
   git rev-parse HEAD
   gh pr view 1 --json state,mergedAt,headRefName,headRefOid,url
   gh pr checks 1
   ```

3. Read [PR-01's brief](prs/pr-01.md), [its roadmap row](pr-roadmap.md#pr-01), progress,
   and [ADR-0003](../architecture/decisions/0003-documentation-authority.md). Load only
   relevant product sections/ADRs/source. Do not restart the foundation or open a
   replacement PR. Review feedback belongs in this existing branch/PR.
4. Run documented checks on any changed snapshot. Record results, limits and pending
   work in Git/PR context, push the checkpoint, and stop for user review. Do not
   begin PR-02 simply because its brief exists or tests pass.

Current next action: review PR #1, including its requirement review and
latest-head validation. Leave it open for the maintainer. If checks are green and
there is no requested change, the task is awaiting user review, not another feature.
No provider, credential, signing, merge or release work is authorized by this handoff.

## Cross-machine and cross-session coordination

One active writer per feature branch. Before changing Macs, update progress with
actual implementation/tests and this file with remaining work/next action, commit
safe source/docs, and push to the same branch. GitHub PR description/reviews/checks
carry coordination context; stashes, untracked files, local chats and unpushed commits
do not travel. Never force-push away the other Mac's work. Do not store credentials
or per-machine paths here. See [ADR-0002](../architecture/decisions/0002-portable-development.md).

Fresh-session prompt:

> Continue the existing MacHandle PR listed in docs/implementation/pr-coordination.md.
> Read AGENTS.md, progress.md, the active roadmap row/brief, and relevant ADRs.
> Inspect GitHub state and fetch its existing branch before editing. Preserve
> unfinished work and the full product requirements. Implement only this PR's
> requested changes, validate, update evidence/coordination, commit and push, then
> leave the PR open for review. Do not merge, publish, or begin the next work package.

## Merge dependencies and recording completion

Before selecting new work, confirm the preceding PR actually merged and fetch main.
Record the real PR URL, merged timestamp and merge SHA in progress and this register;
update roadmap state in the next authorized PR. A squash merge SHA differs from
the feature-branch SHA. Do not treat GitHub's test merge ref as a completed merge,
pre-fill merge evidence, or push a bookkeeping change directly to protected main.

PR-02 is blocked solely on the PR-01 merge gate. Subsequent dependencies and the
Notes/remote/plugin implementation-or-deferral gates are in the roadmap; there are
no other active implementation branches recorded here. Existing core safety and
source-preservation constraints apply regardless of which Mac performs the work.
