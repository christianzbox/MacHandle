# PR coordination and home-Mac handoff

Updated: 2026-10-29, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 28 acceptance](prs/pr-28.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 28 — Remote MCP readiness and activation decision (legacy PR-28) |
| Branch | codex/remote-mcp-readiness |
| GitHub PR | Pending creation after local gates |
| Dependency | Work package 27, merged in GitHub PR #28 |
| Verified squash/base SHA | c1012935d701224a46146bbed4a5f8850055e030 |
| Merge time | 2026-10-29 11:16:24 America/Detroit (15:16:24 UTC) |
| Authorization | User explicitly requested the next step after merging GitHub PR #28 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending local validation/commit; exact final SHA/checks belong in the PR |
| Next action | Finish checks and open one review PR; stop before merge or package 29 |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

[ADR-0032](../architecture/decisions/0032-remote-mcp-readiness.md),
[compatibility/R1–R6 matrix](../development/remote-mcp.md), conditional account guidance and static
Connections availability notice. Official MCP/OpenAI evidence refreshed 2026-10-29. Private
authenticated tunnel is a future experiment candidate; activation explicitly deferred pending
approved identity/auth/infrastructure setup, signed broker and actual client/security proof.
Engineering owns implementation/acceptance; maintainer owns isolated setup and authorization.

No remote transport/auth implementation, listener, tunnel client, credential, entitlement or provider
change. The existing stdio helper remains synthetic; no personal iCloud, permission prompt, client
configuration or account change. Notes and all existing live gates remain closed. Local use does not
require remote infrastructure. Package 29's brief is planned, not implemented.

Staged gates passed: environment 0.35 s, validation 62.90 s, scan 1.67 s; 442 Swift tests, 23 Python
checks and 51 expected compiler rejections. All 1,233 documentation links/anchors and protected-file/
entitlement checks passed. Native Connections notice/layout inspected; no activation control or
permission prompt, Google Connect disabled. App quit and process exit verified. Exact final-head
repeats and hosted evidence belong in the PR. These checks do not prove remote security.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/remote-mcp-readiness
# First use on another Mac: git switch --track origin/codex/remote-mcp-readiness
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If merged, verify the actual squash SHA before the next authorized package; bookkeeping belongs in
that PR, never directly on main. Push safe checkpoints before switching Macs.

## Copyable next-session prompt

> Continue MacHandle work package 28 on codex/remote-mcp-readiness and its linked PR.
> Read AGENTS, coordination/progress, ADR-0032 and acceptance. Preserve changes, fetch/fast-forward
> and confirm one writer. Prerequisite GitHub PR #28 merged at c1012935d701224a46146bbed4a5f8850055e030.
> Address review feedback only. Keep remote activation deferred under R1–R6; no listener, tunnel,
> credential setup, synthetic trust bypass, private database or personal iCloud access. Notes and
> signed/local/provider gates remain open. Stage/review, run all three gates, commit/push the same PR,
> record exact local/hosted evidence and stop. No merge, auto-merge, release or package 29 work.
