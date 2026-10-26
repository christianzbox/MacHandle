# PR coordination and home-Mac handoff

Updated: 2026-10-26, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not a chat, stash or local cache.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 04 — Permission Policy Engine (legacy specification ID PR-04) |
| Branch | `codex/permission-policy-engine` |
| GitHub PR | [GitHub PR #5 — Add permission policy engine](https://github.com/christianzbox/MacHandle/pull/5), open for user review |
| Dependency | Work package 03, merged in [GitHub PR #4](https://github.com/christianzbox/MacHandle/pull/4) |
| Verified squash/base SHA | `a990e05721e75770df98ba01c2bad2bc5aa731a7` |
| Merge time | 2026-10-26 14:38:37 America/Detroit (18:38:37 UTC), rechecked before branching |
| Authorization | User authorized this package and a review PR on 2026-10-26 |
| Writer | Work Mac only until pushed handoff; home-Mac setup remains unverified |
| Implementation checkpoint | `1435d7710e3218e71be1bca8b8d13ff668b2a876` |
| Next action | User review of GitHub PR #5; exact final head/local/hosted evidence in its description |

**Work-package numbers are not GitHub PR numbers.** Use the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs) and descriptive change
name. Legacy specification IDs, brief paths and anchors remain stable.

## Scope, evidence and limits

PermissionEngine depends only on CoreDomain and adds explicit grants, trusted policy
administration, bound client sessions, exact-request receipts, revocation/generation
checks and resource/field projections. A policy allow is not local write approval.
[ADR-0009](../architecture/decisions/0009-permission-policy-engine.md) records choices,
alternatives and operation sequencing; the [acceptance map](prs/pr-04.md#implementation-and-acceptance)
routes requirements to tests. [Work package 05](prs/pr-05.md) is a planned brief only.

Focused checks: 40 Swift tests (21 policy + 18 domain + 1 foundation) pass with no
failures/skips. Dependency/import guards, positive compiler control and seven expected
rejections pass. The exact staged tree committed as
`1435d7710e3218e71be1bca8b8d13ff668b2a876` passed strict preflight (0.34s), full
validation (14.31s: 40 Swift + 13 Python tests, zero failures/skips, builds/analyze,
format/privacy/whitespace) and pinned history/index secret scans (2.27s, no detected
leaks). 473 local documentation links/anchors/case checks passed; all 31 work packages
and legacy anchors remain; specification/LICENSE are unchanged. The final handoff-only
commit receives fresh standard checks. Its exact head and local/hosted results are
recorded on GitHub PR #5 to avoid self-reference. Older evidence remains historical.

No app policy composition, OS permission request, actual authentication, provider,
network, persistence, local approval issuer, signed sandbox, oldest-OS or home-Mac
behavior is implemented/verified. Unified Contact projection is blocked pending
proven field provenance in packages 24/25. Future operations must revalidate after
suspensions and before dispatch/return, obtain separate write approval and check
current provider state. In-process tests do not prove atomic external execution.
No credentials, real content, entitlements, toolchain or global settings changed.

## Resume on either Mac

Use the pinned Xcode 27.1 (27A9275), Swift 6.4 and SDK 27.0 from setup. Preserve
changes and confirm the other Mac stopped writing before resuming this branch.

```sh
git status --short --branch
git fetch origin --prune
# First checkout on this Mac:
git switch --track origin/codex/permission-policy-engine
# If already present: git switch codex/permission-policy-engine
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read the current GitHub PR's head/reviews/checks before edits. Do not resume the
merged/deleted core-domain branch. If this PR merged, verify its actual squash SHA
and stop for direction; no bookkeeping push to main or automatic next package.
Home setup remains an outstanding device check, not a blocker for this library work.

## Copyable next-session prompt

> Continue MacHandle's permission policy engine, work package 04, on
> codex/permission-policy-engine, GitHub https://github.com/christianzbox/MacHandle/pull/5.
> Read AGENTS, coordination/progress, the focused
> acceptance map and ADR-0009. Use the actual GitHub PR link above, not a guessed
> number from the work package. Predecessor GitHub PR #4 merged at
> a990e05721e75770df98ba01c2bad2bc5aa731a7. Fetch/fast-forward after preserving
> changes and confirming a single writer. Address requested review feedback or
> home setup only. No providers, accounts or prompts. Stage/review, run all three
> standard commands, commit/push the same PR and record exact evidence. Stop for
> user review; do not merge, auto-merge, publish or implement work package 05.
