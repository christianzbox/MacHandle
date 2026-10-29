# PR coordination and home-Mac handoff

Updated: 2026-10-29, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [package 24 acceptance](prs/pr-24.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package | 24 — Contacts discovery and read operations (legacy PR-24) |
| Branch | codex/contacts-read-operations |
| GitHub PR | Pending creation after validation |
| Dependency | Work package 23, merged in GitHub PR #24 |
| Verified squash/base SHA | 03cdcb34173a4ecacb512fe10286a025efc10d60 |
| Merge time | 2026-10-29 09:17:09 America/Detroit (13:17:09 UTC) |
| Authorization | User authorized the next package after GitHub PR #24 merged |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending validated commit; exact final SHA and repeated checks belong in the PR |
| Next action | Complete validation, open one PR and stop for user review |

**Work-package numbers are not GitHub PR numbers.** See [mapping](pr-roadmap.md#work-packages-and-github-prs).

## Scope, evidence and limits

Independent native Contacts opt-in, selected containers and optional detail fields, identifier-only
membership scans with minimal selected-record field fetches, exact underlying identities, trusted
per-connection subsets and three bounded synthetic MCP read tools. Settings v3 preserves independent
legacy grants. [ADR-0029](../architecture/decisions/0029-contacts-reads.md) records alternatives and
constraints; [developer checks](../development/contacts-reads.md) separate synthetic and live evidence.

Staged validation and presentation evidence is recorded in progress once complete; final-head repeats
and hosted CI belong in the PR. No personal contact, OS prompt, real write or client configuration is
used. Signed TCC/sandbox, minimum OS, home Mac, actual linked-record behavior and signed peer/native
pairing remain engineering-owned gates. Contacts notes require a separate restricted entitlement and
consent decision; unified display/persistent identity remain gated. Contacts management package 25
is planned only. Calendar/Reminder live writers remain closed; Notes.app retains its feasibility gate.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0. Preserve changes and confirm the other Mac
stopped writing. Fetch, inspect the linked PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/contacts-read-operations
# First use on another Mac: git switch --track origin/codex/contacts-read-operations
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If merged, verify the actual squash SHA and wait for new direction; bookkeeping belongs in the next
authorized PR, never directly on main. Push safe checkpoints before switching Macs.

## Copyable next-session prompt

> Continue MacHandle work package 24 on codex/contacts-read-operations and its linked PR.
> Read AGENTS, coordination/progress, ADR-0029 and acceptance. Preserve changes, fetch/fast-forward
> and confirm one writer. Prerequisite GitHub PR #24 merged at 03cdcb34173a4ecacb512fe10286a025efc10d60.
> Address review feedback only. Preserve explicit Contacts opt-in, field/subset minimization,
> underlying-record identity and synthetic-only helper. Keep signed/native/runtime gates closed;
> no Contacts writes, restricted notes or Notes.app expansion. Stage/review, run all three gates,
> commit/push the same PR, record exact local/hosted evidence and stop. No merge, auto-merge or release.
