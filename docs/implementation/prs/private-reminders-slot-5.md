# Private Reminders slot 5 — actual desktop client workflow

Branch: `codex/private-slot5-desktop-client`. Status: implemented for review, sample-only.
One authorized review PR; account-free, personal iCloud and permissions untouched.

GitHub PR #38 verified merged at `99f0fda1d571425be6984b09637e513d0356d24a` on
2026-10-30 17:20:39 UTC. Both checks passed on `6a4ea09aca5a1f4384e09311bf48769c811876fe`,
CI 41096174349. The [master plan](../../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line)
owns scope; [ADR-0042](../../architecture/decisions/0042-private-desktop-sample-client.md) records decisions.

## Acceptance

| Outcome | Evidence / boundary |
| --- | --- |
| Reviewable preparation | Signed sample-writes package, unique name/exact command preview; no launch/config mutation during preparation |
| Temporary setup | Documented STDIO route, explicit activation flags, collision refusal, unchanged-entry cleanup and unrelated-setting preservation |
| Native authority | Unchanged selection, peer pairing and exact single-use approvals; client confirmation never substitutes |
| Actual-client workflow | Passed on installed ChatGPT desktop local Codex surface: five tools, reads, six approved changes/readbacks, rejection/preapproval/replay denial and revocation; versions/limits in progress |
| Automated safety | Nine synthetic launcher tests; full gates/exact-head hosted evidence in progress/review PR |
| Scope | No provider/TCC, personal iCloud, paid/employer identity, remote endpoint, public submission or scheduling |

See [progress](../progress.md) for actual-client versions, registration guard observation and cleanup evidence.

Follow the [desktop runbook](../../development/private-desktop-client.md). Keep actual-client blockers
explicit rather than substituting probe evidence. Stop after this review PR. Slot 6 remains the planned
private build/testing handoff and is not started here.
