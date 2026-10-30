# Private Reminders slot 3 — approved simple writes

Branch: `codex/private-slot3-approved-writes`. Status: implementation and sample acceptance for review;
live EventKit writer remains closed. Slot numbers are independent of GitHub PR numbers.

## Scope and prerequisite

GitHub PR #36 merged at `4396d35fa138cfd4f860ac48b594e3cdcb7f62df` on 2026-10-30 16:16:00 UTC.
Both hosted checks passed on `0930f5345d55b87f36d0ee21df211ce2a32e6c9a` in CI 41086543370.
User authorization is one slot 3 review PR, account-free, sample-data testing, personal iCloud untouched.
The [master plan](../../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line)
owns the finish line; specification §4.7 and §8.3 own write safety requirements.

## Implementation and acceptance

[ADR-0040](../../architecture/decisions/0040-private-approved-sample-writes.md) and the
[runbook](../../development/private-sample-writes.md) define the separate signed sample-writes profile,
native exact reviews and read-linked targets, durable dispatch journal, and retained real-provider gates.

| Acceptance | Evidence / boundary |
| --- | --- |
| Native selection and paired identity | Explicit fixed Sample list opt-in and per-launch native approval; both directions retain signed XPC identity. No write approval is inferred from pairing. |
| Create/edit/due/complete/uncomplete/delete | Actual signed external MCP proposals, native exact reviews, later wire commits and readback against the same in-memory source. |
| Stronger deletion consent | Native acknowledgement starts unchecked; approval disabled until checked; engine independently rejects missing acknowledgement. |
| No wire approval, replay or substitution | Extra approved flag rejected; preapproval/replayed commits denied; foreign/expired handles rejected by native resolution. |
| Preconditions and revocation | Synthetic concurrent change after review yields notApplied without dispatch; connection closure invalidates pending authority. |
| Durable journal | Pending intent precedes effects; matching receipts retained after reopen; pending/unknown journal blocks new compositions. Existing lost-receipt/cancellation tests remain required. |
| Real EventKit writes | Unconditionally closed factory, no bypass mode; conflict and isolated TCC/provider acceptance remain open. |

Focused checks and signed native sample acceptance passed. Full staged/final exact-head evidence and
hosted status belong in progress/the review PR. The original read-only/identity regressions remain
required; normal CI never requests TCC or runs the UI/launchd test.

## Remaining work and next action

Stop for review before merge or slot 4. Three later planned slots remain. Live read/write gates remain
explicitly open: engineering/maintainer must authorize a verified isolated environment and resolve
EventKit conflict semantics before enabling a live writer. No personal iCloud, employer signing,
paid account, current permission change or actual desktop-client setup is included.

Reminder contents are in memory; only operation status is durable here. Pending/unknown work is never
replayed/reset; complete recovery is slot 4 and stable identity/upgrade handoff is slot 6. Rebuilding a
sample package is not a recovery procedure. No new PR count or scope change is assumed.
