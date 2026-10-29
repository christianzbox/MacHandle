# PR coordination and home-Mac handoff

Updated: 2026-10-29, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 31 acceptance](prs/pr-31.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 31 — ChatGPT packaging/distribution decision (legacy PR-31) |
| Branch | codex/chatgpt-distribution-readiness |
| GitHub PR | Pending creation; decision implemented for review |
| Dependency | Work package 30, merged in GitHub PR #31 |
| Verified squash/base SHA | 5156700cdb8232720562207e10b1a1afa4807dc2 |
| Merge time | 2026-10-29 12:30:59 America/Detroit (16:30:59 UTC) |
| Authorization | User requested the final numbered package after GitHub PR #31 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending commit; exact final evidence belongs in the PR |
| Next action | Complete validation and open one review PR; stop before merge or activation work |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

[ADR-0035](../architecture/decisions/0035-chatgpt-distribution.md), the
[platform matrix/setup protocol](../development/chatgpt-distribution.md) and
[activation index](activation-backlog.md) deliver an explicit packaging/client/distribution deferral.
Private desktop testing is the preferred candidate after signed local bridge/read proof. Native
Connections explicitly labels ChatGPT unavailable; no new behavior or activation control is added.
The eight future client cases and recurring availability protocol have not run.

No manifest, marketplace, plugin ZIP, account/plan inspection, installation, credential, listener,
tunnel, permission grant, signing, submission, scheduled task, public release or personal iCloud
access. Existing synthetic tests are not ChatGPT or signed provider acceptance. Notes G1–G6,
remote R1–R6, release P1–P5 and signed/native/provider gates remain open. No milestone is accepted.
This is the last original numbered package, not the end of product implementation.

Earlier staged gates passed before final documentation polish: environment 0.44 s, validate
46.74 s, secret scan 1.59 s; 445 Swift tests, 32 Python checks, 51 expected compiler rejections,
native builds/analyzer and privacy checks. The documentation check passed 1,376 local links/anchors
and all 31 roadmap anchors. License/specification/toolchain/CI/entitlements remain unchanged.
Exact final-head repeats and hosted status belong in the PR. The native copy was compiled; no
interactive app/provider acceptance was performed.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/chatgpt-distribution-readiness
# First use on another Mac: git switch --track origin/codex/chatgpt-distribution-readiness
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Select the toolchain per process as described in setup. Do not install a client or launch provider
acceptance to resolve documentation gates. If merged, verify the actual squash SHA in the next
separately authorized work; never push bookkeeping directly to main.

## Copyable next-session prompt

> Continue MacHandle work package 31 on codex/chatgpt-distribution-readiness and its linked PR.
> Read AGENTS, coordination/progress, ADR-0035 and the ChatGPT matrix/activation index. Preserve
> changes, fetch/fast-forward and confirm one writer. GitHub PR #31 merged at
> 5156700cdb8232720562207e10b1a1afa4807dc2. Address review feedback on this PR only. Keep
> packaging/client/public/scheduling activation deferred; no account setup, installation, credential,
> signing, tunnel/listener, native permission, personal iCloud, publication or scheduled task.
> Stage/review, run all three gates, commit/push the same PR and record exact evidence. Stop;
> no merge/auto-merge or automatic follow-up. The activation index offers choices, not authorization.
