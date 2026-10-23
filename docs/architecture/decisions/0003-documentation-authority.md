# ADR-0003: Canonical documentation and durable execution context

Date: 2026-10-23. Status: accepted for the PR-01 documentation foundation.

## Context

The product handoff contains comprehensive requirements and a 31-PR roadmap.
PR-01 initially used a flat Docs directory. The user subsequently requested a
BlackBox-inspired organization with one top-level master implementation plan,
separate requirements/progress/coordination, and focused PR context on either Mac.
An abbreviated roadmap must never erase details from the source specification.

## Decision

Use `plans/MacHandleMasterImplementationPlan.md` as the single execution plan;
`docs/product/master-spec.md` as the canonical complete requirements document;
`docs/implementation/pr-roadmap.md` as the plan's detailed execution register;
`progress.md` for actual implementation/verification/merge evidence; and
`pr-coordination.md` for active branch/PR state and next action. Focused briefs live
in `docs/implementation/prs/`; architecture and decision records live here under
`docs/architecture/`. Setup/testing move to `docs/development/`.

Preserve the original source bytes, including its suggested old file paths. A
[path/authority map](../../README.md) records the replacement navigation. Remove old
copies instead of keeping two live plans or progress ledgers. The original §18
roadmap remains part of the preserved requirements; current execution/status lives
only in this plan's supporting register. Product changes require deliberate source
amendment and an ADR, never silent narrowing by a brief.

Distinguish Planned, In progress, Implemented, Verified and Deferred. Merge is an
independent GitHub fact with a merge SHA; release and live acceptance require their
own evidence. Record both scope and test limits, and a reason/revisit trigger for
any deferral. Conditional future scope is not already deferred or implemented.

AGENTS routes a session to coordination/progress, one roadmap row/brief and relevant
ADRs/product sections. PR updates refresh those records; after the user merges,
the next authorized session records merge evidence in its next PR. Never invent a
future merge SHA, auto-merge, or push bookkeeping directly to main.

## Alternatives and tradeoffs

- Keeping flat Docs names would avoid moving links but would not meet the requested
  ownership split. A case-safe Git migration and explicit path map preserve continuity.
- Copying full requirements into the master plan or every brief makes it hard to
  know which version governs. Linked summaries keep navigation small without losing
  complete constraints. Readers must follow source links for the relevant details.
- Rewriting the supplied specification's embedded prompt would make paths current
  but break byte preservation. Keep it intact and identify superseding guidance.
- A live status table duplicated in plan, roadmap, briefs and progress would drift.
  Each document owns one dimension; links connect delivery state, evidence and PR state.
- Copying BlackBox implementation details would add unrelated requirements. Borrow
  only the organizational separation, not its technology or product conventions.

## Consequences and maintenance

Links must be exact-case and repository-relative for GitHub/Linux as well as macOS.
Validate links/anchors and source preservation during this move, and update tools'
help text, root docs and PR templates. A phase summary is not a requirements audit:
acceptance remains scoped to evidence. Keep ADRs dated with alternatives and
consequences; when superseded, link both decisions instead of erasing the rationale.
