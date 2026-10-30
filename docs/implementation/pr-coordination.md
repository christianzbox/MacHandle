# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [progress](progress.md), [slot 2](prs/private-reminders-slot-2.md),
[ADR-0039](../architecture/decisions/0039-private-selected-reminder-reads.md) and
[acceptance](../development/private-selected-reminders.md). Git/GitHub carry the handoff.

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Private Reminders slot 2 — selected reads |
| Branch | codex/private-slot2-reminder-reads |
| GitHub PR | Preparing review PR; final exact-head evidence will be recorded there |
| Dependency | GitHub PR #35 verified merged, both hosted checks passed on 238aa18c4ac0343eb1283ee36d983d0b4d79939c; CI 41078887126 |
| Verified squash/base SHA | 8675999f309f2463b9c2f9ceda0d69a90f09e0ae |
| Merge time | 2026-10-30 15:53:23 UTC (11:53:23 America/Detroit) |
| Authorization | One slot 2 review PR, account-free, sample-data testing, personal iCloud untouched |
| Writer | Work Mac only; home-Mac setup unverified |
| Next action | Review implementation; stop before merge, live EventKit acceptance or slot 3 |

## Scope and evidence

A separate MacHandlePrivateReminders target composes native opt-in/list/field selection with the
existing signed broker, external MCP relay and public EventKitRemindersProvider. Its default test
profile injects samples and never constructs EventKit. The original provider-free sample target stays
available. Distinct sealed profiles prevent switching sample/provider mode through the helper.
Isolated EventKit requires explicit packaging/launch selection, native isolation acknowledgement and
a separate permission action; its full OS permission is broader than the app's enforced read-only tools.

Native sample acceptance proved no implicit selections, per-launch approval, scoped list/search/detail
reads, hidden-list/notes/foreign-ID/write/approval denial, same-client revocation and cleanup. Synthetic
checks cover current authorization, incomplete/removed inventory and stale results. Exact final-head
local, separate native/process and hosted evidence belongs in the PR. No existing personal Keychain
items, employer certificate, TCC permission, EventKit store, personal iCloud or client config was used.
Task-owned temporary signing keys/keychains and jobs are removed; OS-managed sample containers may remain.

## Open gate and finish line

Slot 2 implementation/sample verification is distinct from real EventKit/TCC acceptance. Engineering +
maintainer own the deferred live gate. Revisit only after separate authorization and confirmation of an
isolated macOS test user with no personal/synced accounts and only synthetic local lists. Do not use a
named sample list within personal iCloud. Account-free list availability and disposable signing/TCC
compatibility are unverified; stop and report any blocker. Do not request permission on this profile.
Four later slots remain, with slot 2's real-provider gate still open. No new PR count or scope expansion
is assumed. Actual desktop client remains slot 5 and durable identity/install handoff slot 6.

## Resume on either Mac

Preserve changes, confirm one writer, fetch and inspect actual GitHub state, then fast-forward the same
branch. Use the pinned toolchain per process from [setup](../development/setup.md).

```sh
git status --short --branch
git fetch origin --prune
git switch codex/private-slot2-reminder-reads
# Other Mac first use: git switch --track origin/codex/private-slot2-reminder-reads
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Run the separate native selected-sample and slot 1 regression procedures on the exact final commit.
The isolated EventKit procedure is not authorized by a request to repeat synthetic validation.

## Copyable next-session prompt

> Resume slot 2 review on codex/private-slot2-reminder-reads. Read AGENTS, coordination, progress,
> focused brief, ADR-0039 and acceptance. Verify GitHub state and fast-forward with one writer.
> Keep this PR bounded to selected reads; use injected samples and account-free local fixture signing.
> No personal iCloud, TCC request, real EventKit store, employer signing, existing Keychain items,
> client configuration or billing changes. Run staged/final repository gates and separate native
> sample/process checks; record exact SHA, local/hosted results and open isolated EventKit gate.
> Push the same PR and stop before merge, auto-merge, live acceptance, publication or slot 3.
