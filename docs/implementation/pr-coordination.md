# PR coordination and home-Mac handoff

Updated: 2026-10-29, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 30 acceptance](prs/pr-30.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 30 — Public release engineering readiness (legacy PR-30) |
| Branch | codex/release-engineering-readiness |
| GitHub PR | [GitHub PR #31](https://github.com/christianzbox/MacHandle/pull/31), open for review |
| Dependency | Work package 29, merged in GitHub PR #30 |
| Verified squash/base SHA | 4d47859f390d0fcf7f8e755d173217e8caa47476 |
| Merge time | 2026-10-29 12:07:15 America/Detroit (16:07:15 UTC) |
| Authorization | User requested the next step after merging GitHub PR #30 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | de52b6d8aea342bd6dc6250e6a8f8fbf23f18fe1, pushed; exact final evidence belongs in the PR |
| Next action | Review GitHub PR #31; stop before merge or work package 31 |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

[ADR-0034](../architecture/decisions/0034-release-engineering-readiness.md),
[release engineering/P1–P5](../development/release-engineering.md) and
[account checklist](../development/account-release-checklist.md) implement clean-source local
packaging, strict artifact integrity and explicit distribution refusal. Nine synthetic tests added;
normal validation discovers them without CI permission changes. Dated Apple evidence informs the
future Developer ID/notary runbook and individual/organization account guidance.

No app/provider/entitlement/toolchain change, account setup, credential, signing, notarization,
remote activation, upload, release/tag or personal iCloud access. The rehearsal never launches an app.
Current production signing/helper/profile and signed/live/compatibility acceptance remain open P1–P5;
Notes/remote retain G1–G6/R1–R6. Package 31 is conditional planned only. The following evidence is scoped to the stated snapshot.

Earlier staged gates passed: environment 0.22 s, validate 38.86 s, secret scan 1.71 s;
445 Swift tests, 32 Python checks, 51 expected compiler rejections, native Debug/Release/analyzer,
formatting, SwiftPM build and privacy/diff checks. All 1,322 local documentation links/anchors and
31 roadmap anchors passed; license/specification/toolchain/CI/entitlements are unchanged.

Clean-source integration on `de52b6d8aea342bd6dc6250e6a8f8fbf23f18fe1` passed in 25.08 s from a
fresh checkout and output path containing spaces. The 1,625,473-byte arm64 ZIP has only the three
reviewed bundle files, exact source SHA and verified hashes. An ignored synthetic private marker
was excluded. Dirty source and in-checkout output were rejected; existing output remained unchanged;
`--require-distributable` returned 2 as required. No app launched, credential used or artifact uploaded.
These checks prove the local development profile only, not signed/notary/live/Intel/minimum-OS behavior.
Exact final-head gate repeats and hosted results belong in the linked PR.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/release-engineering-readiness
# First use on another Mac: git switch --track origin/codex/release-engineering-readiness
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

The packaging wrapper requires a clean committed checkout; output must be new and outside Git/cloud
folders. Verify the manifest's source SHA and expect distribution refusal. Never transfer credentials
or artifacts as Git source. If merged, verify the actual squash SHA before the next authorized package.

## Copyable next-session prompt

> Continue MacHandle work package 30 on codex/release-engineering-readiness and its linked PR.
> Read AGENTS, coordination/progress, ADR-0034 and release gates/acceptance. Preserve changes,
> fetch/fast-forward and confirm one writer. GitHub PR #30 merged at
> 4d47859f390d0fcf7f8e755d173217e8caa47476. Address review feedback only after the PR is opened.
> Keep rehearsal artifacts explicitly non-distributable and use synthetic fixtures only. No personal
> iCloud, account setup, credential, signing/notary/upload, production identity, live activation,
> release or tag. Keep signed/provider, Notes and remote gates closed. Stage/review, run all three
> gates, commit/push the same PR and record exact evidence. Stop; no merge/auto-merge or package 31.
