# PR coordination and home-Mac handoff

Updated: 2026-10-29, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 25 acceptance](prs/pr-25.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 25 — Authorized Contacts management (legacy PR-25) |
| Branch | codex/authorized-contacts-management |
| GitHub PR | [GitHub PR #26](https://github.com/christianzbox/MacHandle/pull/26), open for review |
| Dependency | Work package 24, merged in GitHub PR #25 |
| Verified squash/base SHA | 472981db82768cc6420c643e90e596f8ab805ccc |
| Merge time | 2026-10-29 10:19:39 America/Detroit (14:19:39 UTC) |
| Authorization | User explicitly authorized work package 25 and one review PR |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | 6bffbce60a6bf99eb43a461a33adab7f64e428f1, pushed; exact final SHA/checks belong in the PR |
| Next action | Review GitHub PR #26; stop before merge or package 26 |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

Independent Contacts create/update/delete approval, exact underlying-record observation, selected
fields, heightened deletion acknowledgement/phrase, dedicated intent/receipt journal and restart
containment, gated public Contacts save adapter, three fixed native samples and two synthetic MCP
tools. No wire confirmation or saved write grants. [ADR-0030](../architecture/decisions/0030-contacts-management.md)
records alternatives and owned limits; [developer checks](../development/contacts-management.md)
separate synthetic and live evidence.

The first full staged gates passed: environment 0.20 s, validation 94.13 s, secret scan 1.89 s;
442 Swift tests, 23 Python checks and 51 negative compiler probes. Official SDK legacy/modern/auto
and 1,131 documentation links passed. Native sample update/cancel and two-part deletion controls
were inspected, cancelled and app quit. The final implementation checkpoint also passed all staged
gates after a copy clarification: environment 0.47 s, validation 68.21 s, scan 2.26 s. Exact final-head
repeats and hosted CI belong in the PR. No personal contact, OS prompt, real save, client setup,
production store, signing or entitlement change is used. Engineering retains signed peer/native
review/current-OS and writable-container integration, isolated linked-record/conflict/minimum-OS
acceptance, postal fidelity/wire limits, restricted notes and unknown recovery/retention gates.
Calendar/Reminder live writers remain closed. Package 26 Notes feasibility is planned only.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/authorized-contacts-management
# First use on another Mac: git switch --track origin/codex/authorized-contacts-management
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If merged, verify the actual squash SHA and wait for new direction; bookkeeping belongs in the next
authorized PR, never directly on main. Push safe checkpoints before switching Macs.

## Copyable next-session prompt

> Continue MacHandle work package 25 on codex/authorized-contacts-management and its linked PR.
> Read AGENTS, coordination/progress, ADR-0030 and acceptance. Preserve changes, fetch/fast-forward
> and confirm one writer. Prerequisite GitHub PR #25 merged at 472981db82768cc6420c643e90e596f8ab805ccc.
> Address review feedback only. Preserve independent Contacts approvals, exact underlying targets,
> deletion phrase/acknowledgement, dedicated journal and synthetic-only helper. Keep live writers,
> signed/native/runtime gates closed. Do not expand restricted notes/postal scope or begin Notes
> feasibility automatically. Stage/review, run all three gates, commit/push the same PR, record exact
> local/hosted evidence and stop. No merge, auto-merge or release.
