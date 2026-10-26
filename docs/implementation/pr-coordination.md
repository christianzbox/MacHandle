# PR coordination and home-Mac handoff

Updated: 2026-10-26, America/Detroit. Read [setup](../development/setup.md) and
[progress](progress.md). Git/GitHub carry the handoff, not a chat, stash or local cache.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 05 — Native Application Foundation (legacy specification ID PR-05) |
| Branch | `codex/native-application-foundation` |
| GitHub PR | [GitHub PR #6 — Build native application foundation](https://github.com/christianzbox/MacHandle/pull/6), open for user review |
| Dependency | Work package 04, merged in [GitHub PR #5](https://github.com/christianzbox/MacHandle/pull/5) |
| Verified squash/base SHA | `0cdac4bd5845b2b167a48c00332ef5ddf5080606` |
| Merge time | 2026-10-26 14:57:29 America/Detroit (18:57:29 UTC), rechecked before branching |
| Authorization | User authorized this package and a review PR on 2026-10-26 |
| Writer | Work Mac only until pushed handoff; home-Mac setup remains unverified |
| Implementation checkpoint | `2f881edf3cf988baa0e7550489460e1e8cc75363` |
| Next action | User review of GitHub PR #6; exact final-head local/hosted evidence in its description |

**Work-package numbers are not GitHub PR numbers.** Use the
[roadmap mapping](pr-roadmap.md#work-packages-and-github-prs) and descriptive change
name. Legacy specification IDs, brief paths and anchors remain stable.

## Scope, evidence and limits

Native navigation, menu-bar presence, Settings and synthetic connection previews now
compose the policy engine through explicit application dependencies. Connections start
disabled; no selection grants nothing. Old results disappear while policy updates,
fresh sessions revalidate current receipts, and preview policies never grant writes.
History and preview settings reset on process exit. [ADR-0010](../architecture/decisions/0010-native-application-foundation.md)
and the [acceptance map](prs/pr-05.md#implementation-and-acceptance) record decisions,
tests and limitations. [Work package 06](prs/pr-06.md) is a planned brief only.

The exact staged tree committed as `2f881edf3cf988baa0e7550489460e1e8cc75363`
passed strict preflight (0.28s), full validation (34.52s: 48 Swift + 13 Python tests,
zero failures/skips, compiler boundaries, builds/analyze, format/privacy/whitespace)
and pinned history/index secret scans (1.83s; no detected leaks). 497 local doc
links/anchors/case checks passed; all 31 work packages/legacy anchors remain.
The final handoff-only commit receives fresh checks recorded on GitHub PR #6. Work-Mac default locally signed launch,
accessible labels/roles, keyboard navigation/Settings, system-light/dark appearance,
empty-selection denial, selected-read allow, revoke/activity and close-versus-quit
were inspected. Direct status-item click/reopen needs manual review because the
current automation surface does not expose it. Settings height was increased
for readability and reinspected; a fresh launch reset both samples and appearance.

No provider, OS permission request, account authentication, network, persistence,
local approval issuer, background work or login registration was added. No live,
minimum-OS, home-Mac, distribution or comprehensive accessibility proof is claimed.
Specification/LICENSE, entitlements, toolchain and repository protections are preserved.
Final exact-head local and hosted results belong on the GitHub PR, separately.

## Resume on either Mac

Use the pinned Xcode 27.1 (27A9275), Swift 6.4 and SDK 27.0 from setup. Preserve
changes and confirm the other Mac stopped writing before resuming this branch.

```sh
git status --short --branch
git fetch origin --prune
# First checkout on this Mac:
git switch --track origin/codex/native-application-foundation
# If already present: git switch codex/native-application-foundation
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Read this branch's current GitHub PR head/reviews/checks before edits. Do not resume
the merged policy-engine branch. If this PR merged, verify the actual squash SHA and
stop for direction; no bookkeeping push to main or automatic next package.
Home setup remains an outstanding device check, not a blocker for this preview.

## Copyable next-session prompt

> Continue MacHandle's native application foundation, work package 05, on
> codex/native-application-foundation. Read AGENTS, coordination/progress, the current
> GitHub PR linked above, ADR-0010 and the focused acceptance map. The predecessor
> GitHub PR #5 merged at 0cdac4bd5845b2b167a48c00332ef5ddf5080606. Fetch/fast-forward
> after preserving changes and confirming one writer. Address requested review
> feedback or home setup only. Verify the menu-bar status-item click/reopen path if
> available. No providers, accounts or permission prompts. Stage/review, run all three
> standard commands, commit/push the same PR and record exact evidence. Stop for user
> review; do not merge, auto-merge, publish or implement work package 06.
