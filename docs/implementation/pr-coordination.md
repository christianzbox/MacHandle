# PR coordination and home-Mac handoff

Updated: 2026-10-27, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 09 — Google destination client (legacy specification ID PR-09) |
| Branch | `codex/google-destination-client` |
| GitHub PR | [GitHub PR #10 — Add owned Google calendar destination operations](https://github.com/christianzbox/MacHandle/pull/10), open for review |
| Dependency | Work package 08, merged in [GitHub PR #9](https://github.com/christianzbox/MacHandle/pull/9) |
| Verified squash/base SHA | `4d80fabae8b2b3a4482b582a48e974656a02eb3f` |
| Merge time | 2026-10-27 15:15:21 America/Detroit (19:15:21 UTC), verified before branching |
| Authorization | User authorized package 09 and a review PR on 2026-10-27 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | `9b5ad89c59e1ab6183d3fc931965d3924fbd61ef` |
| Next action | User review of GitHub PR #10; exact final-head local/hosted evidence in its description |

**Work-package numbers are not GitHub PR numbers.** Use the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs) and descriptive titles.
Legacy specification IDs, brief paths and anchors remain stable.

## Scope, evidence and limits

Internal GoogleAuthorization components implement app-created destination ownership,
event CRUD with observed If-Match, stable insert plans/explicit unknown-outcome checks,
bounded pagination/backoff and sanitized errors. The authentication actor attaches
credentials privately, coalesces refresh and fences session changes before/after HTTP.
Nineteen new synthetic tests bring the suite to 125 Swift tests; 13 Python tests and
eleven compiler rejection probes remain standard gates. Implementation checkpoint `9b5ad89c59e1ab6183d3fc931965d3924fbd61ef` passed strict
preflight (0.32s), full validation (58.50s: 125 Swift + 13 Python tests, no failures/skips,
eleven probes, universal builds/analyze and repository checks) and pinned history/index
scans (1.99s; no detected leaks). 606 local documentation links/anchors/case checks
passed; all 31 packages/anchors and specification/LICENSE/toolchain/entitlements/CI
were preserved. Final handoff-only changes receive fresh gates; exact final SHA/local/
hosted status is recorded in the PR description. Scanners do not prove data absence.

No app wiring, entitlement, source read consumer, SQLite, planner/executor, MCP or
external connection was added. The client is internal and has no public factory.
No real Google request, Keychain operation or account setup was exercised. Setup and
signed OAuth/privacy gates remain open. Ownership and attempted-operation records are
memory-only, not durable or a cross-Mac lock; activation must wait for persistence and
single-writer enforcement. See [ADR-0014](../architecture/decisions/0014-google-destination-client.md),
[acceptance](prs/pr-09.md#implementation-and-acceptance), the
[account setup guide](../development/google-auth-setup.md) and [package 10 brief](prs/pr-10.md).

Privacy deferral owner: maintainer/privacy work in packages 09/16; revisit after a
supported account-specific verification flow exists. Signed runtime owner: maintainer/
authentication work after setup and explicit isolated-account authorization. Durable
identity/recovery owners: packages 10/14. Do not bypass these gates by constructing a
fresh actor after an unknown outcome. Prior Calendar, home-Mac and release gates remain.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the
other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/google-destination-client
# If already present: git switch codex/google-destination-client
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's actual GitHub PR/reviews/checks before editing. If merged, verify
the squash SHA and wait for new direction. Record merge bookkeeping in the next
explicitly authorized PR, never directly on main.

## Copyable next-session prompt

> Continue MacHandle work package 09 on codex/google-destination-client and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0014 and acceptance/setup gates.
> Prerequisite GitHub PR #9 merged at 4d80fabae8b2b3a4482b582a48e974656a02eb3f.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. No live setup, privacy acceptance, durable ownership or sync is implied.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 10.
