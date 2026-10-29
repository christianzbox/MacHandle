# PR coordination and home-Mac handoff

Updated: 2026-10-29, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 29 acceptance](prs/pr-29.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 29 — Diagnostics, UX hardening and security audit (legacy PR-29) |
| Branch | codex/diagnostics-security-hardening |
| GitHub PR | [GitHub PR #30](https://github.com/christianzbox/MacHandle/pull/30), open for review |
| Dependency | Work package 28, merged in GitHub PR #29 |
| Verified squash/base SHA | 52cc55be15f0e325d4e5107f59c88da8b18f4b46 |
| Merge time | 2026-10-29 11:31:49 America/Detroit (15:31:49 UTC) |
| Authorization | User requested the next step after merging GitHub PR #29 |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | 91d32b1291932e91c754f0178396f1041613dc30, pushed; exact final SHA/checks belong in the PR |
| Next action | Review GitHub PR #30; stop before merge or package 30 |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

[ADR-0033](../architecture/decisions/0033-diagnostics-support-report.md) and the
[audit findings/gates](../development/diagnostics-security-audit.md) cover current-state diagnostics,
closed-schema report preview/save, recovery navigation and corrected history/retry wording.
Three synthetic privacy tests added. Only new entitlement: user-selected file read/write for native
Save. No network/provider/automation entitlement, live service, dependency or credentials added.

Native disabled-state checks verified labels/layout, keyboard navigation, preview/cancel/save and
exact 423-byte temporary output. A blank initial sheet was found and fixed before acceptance.
No iCloud/service was enabled, permission requested or private store/Keychain inspected. Signed
sandbox, provider end-to-end, live audit wiring, full accessibility and sustained-load evidence
remain owned release gates. Notes G1–G6 and remote R1–R6 stay closed. Package 30 is planned only.

Staged gates passed on this implementation: environment 0.23 s, validate 46.68 s, secret scan
1.55 s. Validation includes 445 Swift tests, 23 Python checks, 51 expected compiler rejections,
formatting, SwiftPM build, Debug/Release Xcode builds and analyzer, indexed privacy and diff checks.
All 1,268 documentation links/anchors and 31 roadmap anchors passed; protected files remain equal
to the merged base, with exactly the reviewed user-selected-file entitlement added. Final-head
repeats after handoff edits and hosted results are recorded in the PR. This is not live acceptance.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/diagnostics-security-hardening
# First use on another Mac: git switch --track origin/codex/diagnostics-security-hardening
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If merged, verify the actual squash SHA before the next authorized package; bookkeeping belongs in
that PR, never directly on main. Push safe checkpoints before switching Macs.

## Copyable next-session prompt

> Continue MacHandle work package 29 on codex/diagnostics-security-hardening and its linked PR.
> Read AGENTS, coordination/progress, ADR-0033 and audit/acceptance. Preserve changes, fetch and
> fast-forward; confirm one writer. Prerequisite GitHub PR #29 merged at
> 52cc55be15f0e325d4e5107f59c88da8b18f4b46. Address review feedback only after the PR is opened.
> Use only synthetic fixtures; preserve personal iCloud. Keep signed/local/provider, Notes and
> remote activation gates closed. Never include content, paths, IDs or raw errors in support output.
> Stage/review, run all three gates, commit/push the same PR and record exact local/hosted evidence.
> Stop for user review. No merge, auto-merge, release or package 30 work.
