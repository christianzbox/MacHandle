# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 18 — MCP Calendar read operations (legacy specification ID PR-18) |
| Branch | codex/mcp-calendar-reads |
| GitHub PR | Pending creation after local gates |
| Dependency | Work package 17, merged in [GitHub PR #18](https://github.com/christianzbox/MacHandle/pull/18) |
| Verified squash/base SHA | 9bcc8b06113990f2002293981fe3f62b3d218092 |
| Merge time | 2026-10-28 14:02:12 America/Detroit (18:02:12 UTC), verified before branching |
| Authorization | User authorized the next work package after GitHub PR #18 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | Complete gates and open one review PR; stop before merge or package 19 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Four strict Calendar read tools in an isolated adapter, bound to one trusted PolicySession
and explicit selection. Availability has no content/IDs; title search follows projection;
details refetch through expiring opaque handles. Current OS and policy revalidation,
partial/unknown coverage, output/registry bounds and synthetic-only composition are explicit.

Seventeen new Swift tests bring totals to 279 Swift + 23 Python checks and 22 negative
compiler probes. Focused tests and official SDK 1.26.0 legacy / client 2.4.0 modern+auto
interoperability passed; full gate snapshot/results will be recorded before handoff.
See [ADR-0023](../architecture/decisions/0023-mcp-calendar-reads.md),
[acceptance](prs/pr-18.md#implementation-and-acceptance),
[developer checks](../development/mcp-calendar-reads.md) and [package 19 brief](prs/pr-19.md).

Live external access remains blocked on signed mutually verified broker reachability,
sandbox/minimum-OS/client acceptance and package 19 identity/persistence/revocation/current
OS invalidation. Engineering/maintainer own those gates after approved identity setup.
No real account/content, credential, permission or client configuration was used. Google
live activation remains independent. The user is developing personally, not releasing.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/mcp-calendar-reads
# If already present: git switch codex/mcp-calendar-reads
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

> Continue MacHandle work package 18 on codex/mcp-calendar-reads and its linked review PR.
> Read AGENTS, coordination/progress, ADR-0023 and the acceptance ledger. Prerequisite
> GitHub PR #18 merged at 9bcc8b06113990f2002293981fe3f62b3d218092. Preserve changes,
> fetch/fast-forward and confirm one writer. Address requested review feedback only.
> Keep synthetic-only execution and signed broker/identity gates. Stage/review, run all
> three gates, commit/push the same PR and record exact local/hosted evidence separately.
> Stop for review. Do not merge, auto-merge, publish or start package 19.
