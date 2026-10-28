# PR coordination and home-Mac handoff

Updated: 2026-10-28, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 16 — Google sync onboarding and preferences (legacy specification ID PR-16) |
| Branch | codex/google-sync-onboarding |
| GitHub PR | [GitHub PR #17 — Add reviewed Google sync onboarding and saved privacy preferences](https://github.com/christianzbox/MacHandle/pull/17), open for review |
| Dependency | Work package 15, merged in [GitHub PR #16](https://github.com/christianzbox/MacHandle/pull/16) |
| Verified squash/base SHA | 29f447b47948b054bc6266a946232bcc826d6881 |
| Merge time | 2026-10-28 11:44:47 America/Detroit (15:44:47 UTC), verified before branching |
| Authorization | User authorized the next package after GitHub PR #16 merged on 2026-10-28 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | User review of GitHub PR #17; do not merge or start package 17 |

**Work-package numbers are not GitHub PR numbers.** See the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs). Legacy IDs/paths remain stable.

## Scope, evidence and limits

Native source/privacy/review/status/pause/disconnect controls compose through a local
model and an internal trusted workflow. Retained reviews never replace provider authority;
whole-plan destructive approval remains independent. Schema v3 saves candidate source
fingerprints and field choices, never an enabled bit or approval. Resume requires a fresh
review; unknown writes block replay. No source-writing capability or MCP dependency.

Eighteen added tests bring totals to 249 Swift + 13 Python and eighteen compiler probes.
Implementation checkpoint `7a31d4d01febba0191843f0fce149f8c01546bdd` passed all three
staged gates (environment 0.20s, validation 27.74s, history/index secret scan 1.55s).
Exact final pushed-head checks and separate hosted status are recorded in [GitHub PR #17 — Add reviewed Google sync onboarding and saved privacy preferences](https://github.com/christianzbox/MacHandle/pull/17). See
[ADR-0021](../architecture/decisions/0021-google-sync-onboarding.md),
[acceptance](prs/pr-16.md#implementation-and-acceptance),
[testing](../development/testing.md#work-package-16-onboarding-coverage) and
[package 17 brief](prs/pr-17.md). Unsigned UI inspection covered setup/default controls only.

The shipped app remains unconfigured. No real account, source content, Keychain credential,
network sync, login registration or permission change was performed. Live/signed account,
private sharing, trusted source/lifecycle composition, recovery/transfer UI and isolated
acceptance remain [owned follow-ups](prs/pr-16.md#open-activation-follow-up--not-a-completed-milestone).
Milestone B is not complete. User is developing personally, not preparing a release;
[account/setup instructions](../development/google-auth-setup.md) preserve that distinction.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm
that the other Mac stopped writing before resuming:

```sh
git status --short --branch
git fetch origin --prune
git switch --track origin/codex/google-sync-onboarding
# If already present: git switch codex/google-sync-onboarding
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

> Continue MacHandle work package 16 on codex/google-sync-onboarding and its linked
> review PR. Read AGENTS, coordination/progress, ADR-0021 and the acceptance/setup ledger.
> Prerequisite GitHub PR #16 merged at 29f447b47948b054bc6266a946232bcc826d6881.
> Preserve changes, fetch/fast-forward and confirm one writer. Address requested review
> feedback only. Keep live activation denied until account/privacy/signed gates are proven.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or start package 17.
