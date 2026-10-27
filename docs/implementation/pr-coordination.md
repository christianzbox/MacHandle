# PR coordination and home-Mac handoff

Updated: 2026-10-27, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 08 — Google OAuth and Keychain (legacy specification ID PR-08) |
| Branch | `codex/google-oauth-keychain` |
| GitHub PR | [GitHub PR #9 — Add Google OAuth and private Keychain credentials](https://github.com/christianzbox/MacHandle/pull/9), open for review |
| Dependency | Work package 07, merged in [GitHub PR #8](https://github.com/christianzbox/MacHandle/pull/8) |
| Verified squash/base SHA | `34c5c55019d805514117cb41c99adc5c67b1ba9a` |
| Merge time | 2026-10-26 16:34:06 America/Detroit (20:34:06 UTC), reverified before branching |
| Authorization | User authorized this package and a review PR on 2026-10-27 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | `a9755768a80c38eacb04a47fa1197a365896b5b8` |
| Next action | User review of GitHub PR #9; final exact-head local/hosted evidence in its description |

**Work-package numbers are not GitHub PR numbers.** Use the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs) and descriptive titles.
Legacy specification IDs, brief paths and anchors remain stable.

## Scope, evidence and limits

GoogleAuthorization implements independent browser PKCE, bounded literal-loopback
callbacks, fixed-endpoint HTTPS exchange/refresh/revoke, private Keychain credentials
and disconnect/cancellation generations. UI receives status/actions only. Google
Connect remains disabled: the maintainer confirmed no Apple developer/OAuth setup yet.
No Google service is constructed, no credential operation or external connection starts,
and app entitlements are unchanged. No Calendar/MCP grant or synchronization is enabled.

See [ADR-0013](../architecture/decisions/0013-google-oauth-keychain.md), the
[acceptance map](prs/pr-08.md#implementation-and-acceptance) and
[account, keys, permissions and activation guide](../development/google-auth-setup.md).
The guide covers preparation now, signed activation later and production release setup;
no accounts, credentials or permissions were provisioned by this PR. Live activation needs confirmed
identities, Google console/client setup, an authorized isolated account, reviewed
composition/network entitlements and signed Keychain/sandbox/OAuth verification.
Owner: maintainer/authentication work; revisit after those prerequisites exist.

Synthetic tests cover protocol/HTTP validation, private storage failure, refresh,
revocation/disconnect and stale completions. Two local tests exercise a real unsandboxed
loopback receiver with synthetic values; no Google account or real Keychain API is used.
Native disabled-state layout was inspected. The staged tree committed as `a9755768a80c38eacb04a47fa1197a365896b5b8` passed
strict preflight (0.44s), full validation (56.85s: 106 Swift + 13 Python tests,
zero failures/skips, builds/analyze, nine compiler probes and repository checks),
and pinned history/index scans (1.37s; no detected leaks). 580 local doc links/anchors/
case checks passed; all 31 packages/anchors retained. The final handoff-only commit
receives fresh gates; exact final-head local/hosted evidence is on GitHub PR #9. Prior Calendar live, home-Mac, minimum-OS/Intel
and release gates remain open. Specification/LICENSE/toolchain and CI protections are
preserved. [Package 09](prs/pr-09.md) is a planned brief only.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the
other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/google-oauth-keychain
# If already present: git switch codex/google-oauth-keychain
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's actual GitHub PR/reviews/checks before edits. If merged, verify
the squash SHA and stop for direction. Record merge bookkeeping in the next authorized
PR, never directly on main. Do not resume the merged Calendar-read branch.

## Copyable next-session prompt

> Continue MacHandle work package 08 on codex/google-oauth-keychain and the linked
> review PR. Read AGENTS, coordination/progress, ADR-0013, acceptance and setup gates.
> Prerequisite GitHub PR #8 merged at 34c5c55019d805514117cb41c99adc5c67b1ba9a.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only unless live setup/testing is separately authorized. The maintainer has
> no Apple developer/Google OAuth setup; do not invent IDs or enable live composition.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 09.
