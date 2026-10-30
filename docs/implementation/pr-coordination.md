# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [progress](progress.md), [slot 3](prs/private-reminders-slot-3.md),
[ADR-0040](../architecture/decisions/0040-private-approved-sample-writes.md) and
[native acceptance](../development/private-sample-writes.md). Git/GitHub carry the handoff.

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Private Reminders slot 3 — approved simple writes |
| Branch | codex/private-slot3-approved-writes |
| GitHub PR | Preparing review PR; exact final-head evidence will be recorded there |
| Dependency | GitHub PR #36 verified merged; both hosted checks passed on 0930f5345d55b87f36d0ee21df211ce2a32e6c9a; CI 41086543370 |
| Verified squash/base SHA | 4396d35fa138cfd4f860ac48b594e3cdcb7f62df |
| Merge time | 2026-10-30 16:16:00 UTC (12:16:00 America/Detroit) |
| Authorization | One slot 3 PR; account-free, sample data, personal iCloud untouched |
| Writer | Work Mac only; home-Mac setup unverified |
| Next action | Review; stop before merge, live writes or slot 4 |

## Scope and evidence

Separate MacHandlePrivateWrites/NativeSampleWrites composition, sealed sample-writes profile, native
Sample list opt-in and connection approval, read-linked opaque targets, exact per-operation native
review, separate deletion acknowledgement, and actual approval-engine/journal dispatch to an in-memory
source. Shared schemas keep relay/catalog aligned. Read-only profiles stay read-only. A concrete sample
factory cannot construct a live writer; the EventKit factory remains unconditionally denied.

Synthetic tests exercise six effects, stale snapshots, replay/foreign/rejected proposals, revocation,
reopened receipts and pending/unknown restart denial. Actual signed native/MCP testing exercises
selection, connection approval, reject, six separate exact approvals/commits, readback, six journal
outcomes and revocation. Final exact-head gates and separate native/process/hosted evidence belong in
the review PR. No EventKit store, TCC request, personal iCloud, employer identity, existing personal
Keychain items or actual-client configuration was used. Only disposable task-owned signing keys and
keychains; temporary jobs/packages removed. UUID/state journals and OS-managed sample containers remain.

## Open gates and finish line

Only operation status is durable; sample Reminder contents reset on a new process. A rebuilt sample
identity/store is not a recovery procedure. Full lifecycle/reconciliation is slot 4, actual desktop
client slot 5, stable private identity/install/upgrade handoff slot 6. Three later slots remain.

Live EventKit writes remain closed because cross-app conflict semantics are unresolved; read TCC/local
list availability is also unverified. Engineering/maintainer own those gates. Revisit only with an
explicitly accepted provider conflict contract and separately authorized, verified isolated macOS test
account containing synthetic local lists. Do not use personal iCloud or reinterpret sample proof as
live readiness. No new PR count or paid membership assumption is introduced.

## Resume on either Mac

Preserve changes; confirm one writer, fetch/inspect actual GitHub state, fast-forward the same branch.
Use [setup](../development/setup.md) for the pinned per-process toolchain.

```sh
git status --short --branch
git fetch origin --prune
git switch codex/private-slot3-approved-writes
# Other Mac first use: git switch --track origin/codex/private-slot3-approved-writes
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Run separate signed sample-write, selected-read, native pairing and external peer regressions on the
final commit. No live provider/TCC procedure is authorized by a request to repeat sample validation.

## Copyable next-session prompt

> Resume slot 3 review on codex/private-slot3-approved-writes. Read AGENTS, coordination, progress,
> brief, ADR-0040 and native acceptance. Verify GitHub state, preserve changes and fast-forward with
> one writer. Keep sample-only concrete writers and sealed profile isolation. No personal iCloud,
> TCC, EventKit store, employer identity, existing Keychain items, billing or desktop-client changes.
> Run full staged/final repository gates and separate signed sample/process acceptance; record exact
> SHA and local/hosted limits. Push the same PR and stop before merge, live activation or slot 4.
