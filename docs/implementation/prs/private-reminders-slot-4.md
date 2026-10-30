# Private Reminders slot 4 — lifecycle and recovery

[GitHub PR #38](https://github.com/christianzbox/MacHandle/pull/38).
Branch: `codex/private-slot4-recovery`. Status: implemented for review, sample-only.
One authorized PR; account-free, personal iCloud and permissions untouched.

## Prerequisite and scope

GitHub PR #37 merged at `69b5445c794f03eeb0d06acd12472aee97031239` on 2026-10-30 16:56:14 UTC.
Both checks passed on `5e757ccf5b8a510eb67ed655650c7b5affafd0f9`, CI run 41092336083.
The [master plan](../../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line)
owns the remaining finish line; [ADR-0041](../../architecture/decisions/0041-private-sample-lifecycle-recovery.md)
records decisions, alternatives and limits.

## Acceptance

| Outcome | Evidence / boundary |
| --- | --- |
| Orderly stop and native Quit | Admission closes before suspension; admitted commits drain through actual receipt/outcome delivery. Concurrent stop callers wait. |
| Lost reply is not rollback | Deterministic tests suspend before/after effect; closed reply denied while native actual outcome is preserved. |
| Crash/restart | Signed disposable app is killed and the same package reopens its journal; access/selection off, old approvals and handles denied. |
| Disconnect/fresh session | Helper disconnect stops native session. Explicit fresh action, renewed selection, pairing and exact review required; no silent reconnect. |
| Recovery inspection | Native counts and bounded operation UUID/status rows without starting a connection/provider. No receipt rewrite, replay or reset. |
| Uncertain outcome | Pending/unknown remain visible and block new composition. No evidence means no automatic reconciliation; absence in a fresh in-memory source proves nothing about prior effects. |
| Scope | Real EventKit writer still unconditionally denied; no TCC, personal iCloud, paid account or actual desktop-client configuration. |

Focused tests and signed sample crash/relaunch/disconnect acceptance passed during implementation.
Staged/final full-gate and hosted evidence will be recorded in progress/the review PR. Provider-window
crash semantics use deterministic tests; no runtime fault switch is added just to force that window.

## Handoff

Follow the [native recovery runbook](../../development/private-sample-recovery.md). Preserve same-package
journals, even when unknown; never rebuild/delete as recovery. Temporary signing keys/packages/jobs
are removed by the harness, but sample UUID/state journals remain in their own sandbox containers.

Stop for review. Slots 5 (actual desktop client) and 6 (private install/testing handoff) remain planned
and unauthorized. The live conflict/isolated permission gates still belong to engineering/maintainer;
revisit only after separate authorization and evidence. No new PR count or provider-readiness claim.
