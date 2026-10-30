# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [progress](progress.md),
[slot 5](prs/private-reminders-slot-5.md),
[ADR-0042](../architecture/decisions/0042-private-desktop-sample-client.md) and
[desktop acceptance](../development/private-desktop-client.md).

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Private Reminders slot 5 — actual desktop client workflow |
| Branch | codex/private-slot5-desktop-client |
| GitHub PR | Pending creation; exact final-head evidence will be recorded there |
| Dependency | GitHub PR #38 verified merged; both checks passed on 6a4ea09aca5a1f4384e09311bf48769c811876fe; CI 41096174349 |
| Verified squash/base SHA | 99f0fda1d571425be6984b09637e513d0356d24a |
| Merge time | 2026-10-30 17:20:39 UTC |
| Authorization | One slot 5 PR; account-free, sample data, personal iCloud untouched; separate sample test chat explicitly authorized |
| Writer | Work Mac only; home-Mac setup unverified |
| Next action | Finish checks, open review PR, stop before merge or slot 6 |

## Scope and evidence

Repeatable synthetic-only preparation, reviewable STDIO command preview and temporary desktop
registration with targeted cleanup. Native selection/pairing/exact approval and journal semantics
remain unchanged. Client acceptance uses a separately authorized local desktop test chat and the
actual MCP tools, with native app UI actions; no SDK/probe substitution or client UI-control bypass.

Nine launcher safety tests passed. Full staged/final-head and hosted evidence belongs in the review
PR. Actual desktop local Codex acceptance passed all six changes and negative cases; native journal
showed six applied and zero unresolved. Temporary client entry/job, cached task helper and package
were removed; unrelated settings were preserved during successful registration/cleanup. No EventKit
store, TCC request, personal iCloud, employer signing or existing Keychain item was used. Task-owned signing keychains are removed;
sample UUID/state journals and OS-managed sample containers remain.

## Remaining finish line

One later planned slot remains: 6 reproducible private installation and test handoff. The six-slot,
seven-review-PR estimate is unchanged. Live conflict/isolated permission gates still require separately
authorized synthetic-only macOS-account evidence. Unknown sample effects remain blocked; rebuilding
or deleting journals is not recovery. No paid account or live/public readiness claim is introduced.

## Resume on either Mac

Preserve changes and confirm one writer. Fetch and inspect actual GitHub state, then fast-forward this
same branch. Follow [setup](../development/setup.md) for pinned per-process toolchain selection.

```sh
git status --short --branch
git fetch origin --prune
git switch codex/private-slot5-desktop-client
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Desktop package paths, random identities and client entries are local disposable artifacts, not a
portable install. Follow the runbook for targeted cleanup before changing Macs. Do not touch personal
providers or settings to repeat acceptance. Push a safe checkpoint and stop before merge or slot 6.
