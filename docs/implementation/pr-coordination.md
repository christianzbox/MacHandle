# PR coordination and home-Mac handoff

Updated: 2026-10-29, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 26 acceptance](prs/pr-26.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 26 — Apple Notes feasibility/security decision (legacy PR-26) |
| Branch | codex/notes-feasibility-review |
| GitHub PR | Pending creation after local gates |
| Dependency | Work package 25, merged in GitHub PR #26 |
| Verified squash/base SHA | 9704899f45b2a03c37e514a206f5b75d7c075122 |
| Merge time | 2026-10-29 10:44:40 America/Detroit (14:44:40 UTC) |
| Authorization | User directed continued building, preserving personal iCloud and leaving live testing for later |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending local validation/commit; exact final SHA/checks belong in the PR |
| Next action | Finish checks and open one review PR; stop before merge or package 27 |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

Documentation-only [ADR-0031](../architecture/decisions/0031-notes-feasibility.md),
[capability matrix and isolated protocol](../development/notes-feasibility.md), package 26 acceptance
and planned package 27 deferral brief. Public source and shipped scripting terminology review only.
Inherited Standard commands/groups are included; no declaration is presented as runtime proof.

Decision: defer Notes activation and the required sandboxed synthetic prototype pending isolated
fixture/signing setup and explicit authorization. Engineering owns G1–G6; maintainer owns setup.
No permanent infeasibility claim. No Notes launch, Apple events, Shortcuts inventory/execution,
permission prompt, personal data, account setting, private database, provider/helper behavior,
entitlement or signing change. Other live factories remain closed. Staged gates passed: environment 0.28 s, validation 37.23 s, scan 1.57 s; 442 Swift tests,
23 Python checks and 51 negative compiler probes. All 1,161 documentation links/anchors, unchanged
protected files/entitlements, documentation-only scope and static reproduction passed. Exact
final-head repeats and hosted evidence belong in the PR; none establishes Notes runtime support.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/notes-feasibility-review
# First use on another Mac: git switch --track origin/codex/notes-feasibility-review
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If merged, verify the actual squash SHA before the next authorized package; bookkeeping belongs in
that PR, never directly on main. Push safe checkpoints before switching Macs.

## Copyable next-session prompt

> Continue MacHandle work package 26 on codex/notes-feasibility-review and its linked PR.
> Read AGENTS, coordination/progress, ADR-0031 and acceptance. Preserve changes, fetch/fast-forward
> and confirm one writer. Prerequisite GitHub PR #26 merged at 9704899f45b2a03c37e514a206f5b75d7c075122.
> Address review feedback only. Keep all Notes capabilities and its runtime prototype deferred until
> the isolated signed fixture gate is authorized and passed. No personal iCloud access, Automation
> prompts, script/shortcut execution, private database or sandbox workaround. Distinguish public
> terminology from runtime proof. Stage/review, run all three gates, commit/push the same PR, record
> exact local/hosted evidence and stop. No merge, auto-merge, release or package 27 implementation.
