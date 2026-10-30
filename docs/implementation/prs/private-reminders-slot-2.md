# Private Reminders slot 2 — selected reads

Branch: `codex/private-slot2-reminder-reads`. Status: implementation/sample verification for review;
real EventKit/TCC acceptance remains open. Slot numbers are independent of GitHub PR numbers.

## Scope and prerequisite

GitHub PR #35 merged at `8675999f309f2463b9c2f9ceda0d69a90f09e0ae` on 2026-10-30 15:53:23 UTC.
Both hosted checks passed on `238aa18c4ac0343eb1283ee36d983d0b4d79939c` in CI run 41078887126.
The user authorized slot 2 only, account-free, sample-data testing, personal iCloud untouched.
The [master plan](../../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line)
owns the finish line; specification §3.2, §4.1–4.2 and §13.4 own requirements.

## Implementation and acceptance

[ADR-0039](../../architecture/decisions/0039-private-selected-reminder-reads.md) adds the native setup,
explicit list/field grants, shared scoped reader, selected MCP search/detail path, and an isolated
EventKit composition using the existing public provider. The [runbook](../../development/private-selected-reminders.md)
separates sample verification from real OS acceptance. No write tool or native mutation provider is added.

| Acceptance | Evidence and boundary |
| --- | --- |
| Disabled first; independent OS opt-in | Injected permission counters prove no discovery/request before native opt-in; isolated acknowledgement required; denial exposes no lists. No real prompt run. |
| Native list and field selection | Nothing preselected; complete unique inventory required; selected list/field snapshot revalidated before connecting. Real native sample selection tested. |
| External selected reads | Signed package plus actual native selection/approval, external Python MCP search and details, title/completion projection; hidden list/notes and foreign IDs denied. |
| Current permission and stale results | Synthetic permission loss before/during reads, missing selected list, incomplete discovery, stop during discovery, store-change and foreground permission invalidation. |
| Revocation and writes | Native Stop clears selection and denies same client; wire approval and mutation names denied. |
| Public EventKit package | Compiled composition; sealed distinct profile, native opt-in, purpose key and scoped sandbox entitlement. Local signing and account-free EventKit runtime acceptance are not claimed. |

Focused synthetic checks and current-Mac native acceptance passed; full staged/final-head commands,
counts, timings and hosted evidence belong in progress/the PR. The earlier slot 1 identity, tamper,
wrong-peer and cleanup checks remain required regressions. Normal CI never launches EventKit or UI.

## Remaining gate and next action

Review this implementation PR. Real EventKit/TCC acceptance is deferred by the sample-only authorization
and absence of a verified isolated test environment. Owners: engineering + maintainer. Trigger: separate
authorization and an isolated macOS account containing only synthetic local lists; execute the runbook
and record actual results. If account-free local lists or signing/TCC cannot work, report the concrete
blocker before changing scope. Personal iCloud remains excluded. Four later planned slots remain;
slot 2's live gate is still open. Do not merge, start slot 3, create accounts or alter billing settings.
