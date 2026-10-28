# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 19 — MCP connection authentication and revocation (legacy specification ID PR-19) |
| Branch | codex/mcp-connection-identity |
| GitHub PR | Pending validation and review PR creation |
| Dependency | Work package 18, merged in [GitHub PR #19](https://github.com/christianzbox/MacHandle/pull/19) |
| Verified squash/base SHA | defc08efb19028d4a9a5781c66b31748d217e9eb |
| Merge time | 2026-10-28 15:03:57 America/Detroit (19:03:57 UTC), verified before branching |
| Authorization | User authorized the next work package after GitHub PR #19 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending validation and push |
| Next action | Validate and open the work package 19 review PR; stop before merge or package 20 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Trusted channel-bound local review, saved permission candidates, revocation/cancellation,
current OS invalidation and bounded content-free audit. Settings never restore active
sessions. Synthetic Calendar tools now use the resulting read lease. The production peer
verifier defaults denied; no live factory or native pairing screen is introduced.

Eighteen new tests bring totals to 297 Swift + 23 Python checks and 26 negative compiler
probes. Full gates and SDK checks remain pending; exact checkpoint, final-head and hosted
outcomes will be recorded in the review PR. See
[ADR-0024](../architecture/decisions/0024-mcp-connection-identity.md),
[acceptance](prs/pr-19.md#implementation-and-acceptance) and
[developer checks](../development/mcp-connections.md).

Engineering/maintainer own the signed helper/broker, native review, current OS/transport
integration, sandbox/minimum-OS and actual desktop-client acceptance after approved identity
setup, before any personal-data activation. No real account/content, credential, permission
or client configuration was used. Google live activation remains independent. The user is
developing personally, not releasing. [Package 20](prs/pr-20.md) is preparation only.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/mcp-connection-identity
# If already present: git switch codex/mcp-connection-identity
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's GitHub PR/reviews/checks before editing. If merged, verify the actual
squash SHA and wait for new direction. Record merge bookkeeping in the next authorized PR,
never directly on main. Supplemental SDK dependencies are disposable and outside Git.

## Copyable next-session prompt

> Continue MacHandle work package 19 on codex/mcp-connection-identity and its linked PR.
> Read AGENTS, coordination/progress, ADR-0024 and the acceptance ledger. Prerequisite
> GitHub PR #19 merged at defc08efb19028d4a9a5781c66b31748d217e9eb. Preserve changes,
> fetch/fast-forward and confirm one writer. Address requested review feedback only.
> Keep synthetic-only execution and signed broker/native review gates. Stage/review, run
> all three gates, commit/push the same PR and record exact local/hosted evidence separately.
> Stop for review. Do not merge, auto-merge, publish or start package 20.
