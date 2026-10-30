# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [progress](progress.md),
[slot 6](prs/private-reminders-slot-6.md),
[ADR-0043](../architecture/decisions/0043-private-test-installation.md) and
[private testing handoff](../development/private-testing-handoff.md).

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Private Reminders slot 6 — private installation and testing handoff |
| Branch | codex/private-slot6-test-handoff |
| GitHub PR | Pending creation; final-head evidence will be recorded there |
| Dependency | GitHub PR #39 verified merged; both checks passed on 9ae9d9fb4ba6c098583c54c2e446bd23c681758e; CI 41100612018 |
| Verified squash/base SHA | eb0002146b4efb5ae39c3f5e7131620c586fc102 |
| Merge time | 2026-10-30 17:59:35 UTC |
| Authorization | One slot 6 PR; account-free, sample data, personal iCloud untouched |
| Writer | Work Mac only; home-Mac setup unverified |
| Next action | Finish acceptance/checks and open review PR; stop before merge or further implementation |

## Scope and evidence

Clean-source Release build, reusable same-package identity, frozen launcher/runtime and file manifest,
verification before launch, targeted session cleanup and a first-session testing checklist. In-place
upgrade/key continuity and journal migration are unsupported; reviewed sibling builds retain previous
evidence and cannot be used to resolve unknown effects. No private key is retained.

Seven focused installation tests and the nine desktop launcher tests pass. Real clean-source build,
prebuilt native restart acceptance and the standard gates are pending. No EventKit store, TCC request,
personal iCloud, employer signing or existing Keychain identity is used.

## Remaining finish line

This is slot 6, the final planned engineering handoff in the six-slot sample Reminders track. No new
slot or automatic follow-up is introduced. Maintainer hands-on checklist acceptance remains separate.
Live Reminders/provider/conflict gates and the broader app remain explicitly unfinished; scope and
estimate that phase before further implementation. No personal-data activation or public release.

## Resume on either Mac

Preserve changes and confirm one writer. Fetch and inspect actual GitHub state, then fast-forward this
same branch. Follow [setup](../development/setup.md) for pinned per-process toolchain selection.

```sh
git status --short --branch
git fetch origin --prune
git switch codex/private-slot6-test-handoff
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Private installations stay at their original physical path on the designated Mac. Follow the runbook for targeted cleanup before changing Macs. Do not touch personal
providers or settings to repeat acceptance. Push a safe checkpoint and stop before merge or another phase.
