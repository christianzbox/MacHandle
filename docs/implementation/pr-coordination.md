# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 17 — MCP server foundation (legacy specification ID PR-17) |
| Branch | codex/mcp-server-foundation |
| GitHub PR | [#18 — Add bounded synthetic MCP server and protocol compatibility](https://github.com/christianzbox/MacHandle/pull/18), open for review |
| Dependency | Work package 16, merged in [GitHub PR #17](https://github.com/christianzbox/MacHandle/pull/17) |
| Verified squash/base SHA | 4d1bc9467b9b827e61fbf493004f4d5ae525982a |
| Merge time | 2026-10-28 13:26:41 America/Detroit (17:26:41 UTC), verified before branching |
| Authorization | User authorized work package 17 and a review PR after GitHub PR #17 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | 0759cb9345c98dc4d7c8e9f138c49f27c0068fe5, pushed; later documentation handoff commit is identified in the PR |
| Next action | Review GitHub PR #18; stop before merge or package 18 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Separate `machandle-mcp --synthetic` executable with four fixed mocks, modern per-request
metadata and legacy initialization, strict schemas/errors, bounded framing/concurrency,
cancellation and EOF/signal/output-pressure handling. No provider/credential/policy/app
imports, live broker, listener, client installation or app embedding.

Thirteen added Swift and nine subprocess tests bring totals to 262 Swift + 22 Python,
with twenty compiler probes. All three gates passed on the implementation checkpoint's
staged tree: environment 0.20 s, validation 29.42 s, secret scan 1.46 s. Documentation
checks passed 857 local links and 31 roadmap anchors. The PR records final pushed SHA,
its gate rerun and hosted checks separately. Supplemental official SDK 1.26.0 legacy and client 2.4.0 pinned-modern/auto checks
passed against actual subprocesses. See [ADR-0022](../architecture/decisions/0022-mcp-server-foundation.md),
[acceptance](prs/pr-17.md#implementation-and-acceptance),
[developer checks](../development/mcp-foundation.md) and [package 18 brief](prs/pr-18.md).

Signed external helper → authenticated broker, peer rejection, sandbox/minimum OS and
actual desktop-client acceptance remain owned by engineering/maintainer after approved
identity setup. Package 18 can build synthetic read adapters; live external reads need
that gate and package 19 identity/revocation. No personal data, credential, permission or
client configuration was used. Google live activation stays independently blocked.
The user is developing personally and is not preparing a public release.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/mcp-server-foundation
# If already present: git switch codex/mcp-server-foundation
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's actual GitHub PR/reviews/checks before editing. If merged, verify
the squash SHA and wait for new direction. Record merge bookkeeping in the next
explicitly authorized PR, never directly on main. SDK installs are supplemental only;
normal validation requires no npm dependencies or account.

## Copyable next-session prompt

> Continue MacHandle work package 17 on codex/mcp-server-foundation and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0022 and the acceptance ledger.
> Prerequisite GitHub PR #17 merged at 4d1bc9467b9b827e61fbf493004f4d5ae525982a.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. Keep the executable synthetic and preserve signed broker/identity gates.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 18.
