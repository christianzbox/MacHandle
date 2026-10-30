# Private Reminders slot 6 — private installation and testing handoff

Branch: `codex/private-slot6-test-handoff`. Status: in progress; sample-only, account-free.
One authorized review PR. Personal iCloud and provider permissions remain untouched.

GitHub PR #39 verified merged at `eb0002146b4efb5ae39c3f5e7131620c586fc102` on
2026-10-30 17:59:35 UTC. Both checks passed on `9ae9d9fb4ba6c098583c54c2e446bd23c681758e`,
CI 41100612018. Read the [master plan](../../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line),
[ADR-0043](../../architecture/decisions/0043-private-test-installation.md) and
[testing handoff](../../development/private-testing-handoff.md).

| Outcome | Acceptance / limit |
| --- | --- |
| Reproducible procedure | Clean recorded Git archive, pinned Release build, frozen launcher/runtime and source/file manifest; no byte-identical-build claim |
| Stable private installation | Reopen the exact signed package at its final path; same identity/journal, fresh selection/pairing/approvals |
| Verification | Exact inventory/hash/modes, no links, unchanged sample profile/identity, signed package and sandbox-only entitlement |
| Update/removal | No overwrite/in-place migration; reviewed sibling builds retain previous evidence. No journal/container reset |
| Maintainer handoff | Accounts/tools/permission matrix, first-session pass/fail checklist, stop/cleanup and recovery instructions |
| Evidence | Seven focused installation tests passed; clean-source/native restart/full gates and hosted evidence pending |

No new slot is introduced. After review this is the final planned engineering handoff for sample
Reminders; maintainer hands-on acceptance remains explicit. Full-app/live-provider readiness is not
implied. Stop before another phase, merge, personal-data activation or publication.
