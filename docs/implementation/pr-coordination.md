# PR coordination and home-Mac handoff

Updated: 2026-10-29, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 27 acceptance](prs/pr-27.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 27 — Notes deferral and experimental availability (legacy PR-27) |
| Branch | codex/notes-experimental-availability |
| GitHub PR | Pending creation after local gates |
| Dependency | Work package 26, merged in GitHub PR #27 |
| Verified squash/base SHA | 4450809877cc553bfebc7bfa051ac269884e3865 |
| Merge time | 2026-10-29 11:02:10 America/Detroit (15:02:10 UTC) |
| Authorization | User explicitly requested the next piece after merging GitHub PR #27 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending local validation/commit; exact final SHA/checks belong in the PR |
| Next action | Finish checks and open one review PR; stop before merge or package 28 |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

Shared static Notes availability explanation in Overview/Diagnostics, public capability/privacy/setup
copy and the [ADR-0031 follow-up](../architecture/decisions/0031-notes-feasibility.md#work-package-27-availability-follow-up).
Adjacent Diagnostics labels include existing Reminders/Contacts opt-in reads. The
[package 28 brief](prs/pr-28.md) is planned only; no remote feasibility verdict or implementation.

No Notes state, provider, tools, callback, enable control, entitlement or permission request. No
personal iCloud access, Notes launch, script execution, account setting or credential change.
Existing live factories remain closed. The isolated Notes prototype and G1–G6 remain explicitly
deferred, engineering-owned pending maintainer fixture/signing setup and authorization. This package
delivers the deferral path, not runtime Notes support or distribution acceptance.

Staged gates passed: environment 0.41 s, validation 75.37 s, scan 2.45 s; 442 Swift tests, 23 Python
checks and 51 expected compiler rejections. All 1,191 documentation links/anchors and unchanged
protected-file/entitlement checks passed. Native Overview/Diagnostics text/layout inspected with
services off; no permission prompt or provider enable action. App quit and process exit verified.
Exact final-head repeats and hosted evidence belong in the PR. Tests use synthetic data only.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/notes-experimental-availability
# First use on another Mac: git switch --track origin/codex/notes-experimental-availability
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If merged, verify the actual squash SHA before the next authorized package; bookkeeping belongs in
that PR, never directly on main. Push safe checkpoints before switching Macs.

## Copyable next-session prompt

> Continue MacHandle work package 27 on codex/notes-experimental-availability and its linked PR.
> Read AGENTS, coordination/progress, ADR-0031 and acceptance. Preserve changes, fetch/fast-forward
> and confirm one writer. Prerequisite GitHub PR #27 merged at 4450809877cc553bfebc7bfa051ac269884e3865.
> Address review feedback only. Keep Notes informational and unavailable, with no activation path,
> permission prompt, script/shortcut, private database or personal iCloud access. G1–G6 remain open.
> Stage/review, run all three gates, commit/push the same PR, record exact local/hosted evidence and
> stop. No merge, auto-merge, release or package 28 implementation.
