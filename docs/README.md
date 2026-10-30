# Documentation map

Start with [PR coordination](implementation/pr-coordination.md) and
[implementation progress](implementation/progress.md) on either Mac. Read the
active [roadmap entry](implementation/pr-roadmap.md) and its focused brief, then
only the product sections and ADRs it points to. The complete product specification
is preserved; it is not necessary context for every individual PR.

## Work packages versus GitHub pull requests

Use **work package 04 — Permission Policy Engine** for the roadmap step, and
**GitHub PR #N** only for the actual review link. These numbers are independent.
The source specification's legacy `PR-04` label and `prs/pr-04.md` filename remain
stable references; neither means GitHub PR #4. GitHub titles now describe the change
without a roadmap PR-number prefix. The [roadmap mapping](implementation/pr-roadmap.md#work-packages-and-github-prs)
shows actual review links. Historical records retain their original labels.

## Canonical documents

- [Product specification](product/master-spec.md): full product vision, requirements,
  constraints, original roadmap and acceptance criteria, not a compressed summary.
- [Master implementation plan](../plans/MacHandleMasterImplementationPlan.md): the
  one execution plan, with stages, milestone gates and unresolved decision owners.
- [PR roadmap](implementation/pr-roadmap.md): detailed ordered register of all 31
  work packages, dependencies, scoped acceptance and delivery state.
- [Progress](implementation/progress.md): implemented/verified/merged evidence and
  limitations; [coordination](implementation/pr-coordination.md): active PR/branch
  and resume steps; [briefs](implementation/prs/README.md): focused implementation tasks.
- [Architecture overview](architecture/overview.md), [decision records](architecture/decisions/README.md),
  [security model](architecture/security-model.md), and [privacy model](architecture/privacy-model.md).
- [Either-Mac setup and Git handoff](development/setup.md), [testing](development/testing.md),
  [Developer accounts, permissions and Google activation](development/google-auth-setup.md),
  [Reminders read checks](development/reminders-reads.md),
  [release policy](releases.md), and [agent instructions](../AGENTS.md).

## Source preservation and relocated paths

`product/master-spec.md` is the complete v5.0 handoff supplied on 2026-10-23, moved
without changing any bytes during this consolidation. Its import SHA-256 is
`1f40466b469858e5f0e47fe88ae712d2b029e13c1e74c027882f615bbedf242d`.
Git retains the original and subsequent history. Future product amendments must be
explicitly reviewed and recorded; do not silently replace requirements with shorter
briefs or hold a second copy of the specification elsewhere.

The source includes suggested old paths and a reusable prompt in sections 15–17,
23–24 and 27. They remain intact for fidelity. The current document locations below
supersede those navigation instructions; use AGENTS/the coordination prompt today.
No compatibility copies or duplicate old plan/status files are maintained.

| Original proposed path | Current canonical destination |
| --- | --- |
| `Docs/MASTER_SPEC.md` | [Product specification](product/master-spec.md) |
| `Docs/PR_PLAN.md` | [Master implementation plan](../plans/MacHandleMasterImplementationPlan.md) for execution governance; [PR roadmap](implementation/pr-roadmap.md) for the detailed register |
| `Docs/CURRENT_STATE.md` | [Progress](implementation/progress.md) for actual evidence; [PR coordination](implementation/pr-coordination.md) for active branch/handoff |
| `Docs/PRs/` | [Focused briefs](implementation/prs/README.md) |
| `Docs/ARCHITECTURE.md` | [Architecture overview](architecture/overview.md) |
| `Docs/ADR/` | [Decision records](architecture/decisions/README.md) |
| `Docs/SECURITY_MODEL.md` / `Docs/PRIVACY_MODEL.md` | [Security](architecture/security-model.md) / [privacy](architecture/privacy-model.md) |
| `Docs/DEVELOPMENT.md` / `Docs/TESTING.md` | [Setup](development/setup.md) / [testing](development/testing.md) |
| `Docs/RELEASES.md` | [Release policy](releases.md) |

The work/home toolchain and this documentation organization are subsequent explicit
PR-01 requirements, recorded in ADR-0002/0003. They preserve the full source and
extend its workflow without changing the product's feature commitments. See the
master plan for document authority and conflict handling. No BlackBox product,
infrastructure, auth, or release conventions were imported.


Work package 23 adds [approved Reminder management](architecture/decisions/0028-reminders-management.md)
with independent observation/confirmation and a dedicated durable journal; live activation remains closed.

Work package 24 adds [Contacts read decisions](architecture/decisions/0029-contacts-reads.md) and
[developer checks](development/contacts-reads.md), with [acceptance](implementation/prs/pr-24.md#implementation-and-acceptance).
Signed/runtime and real MCP access remain gated; package 25 management contracts are described below.

Work package 25 adds [Contacts management decisions](architecture/decisions/0030-contacts-management.md),
[developer checks](development/contacts-management.md) and
[acceptance](implementation/prs/pr-25.md#implementation-and-acceptance). Live writes remain gated;
[package 26](implementation/prs/pr-26.md) records the merged Notes feasibility decision in
[ADR-0031](architecture/decisions/0031-notes-feasibility.md) and
[static evidence/runtime gates](development/notes-feasibility.md). Live Notes and its sandboxed
prototype are explicitly deferred. [Package 27](implementation/prs/pr-27.md) delivers consistent
merged native availability and public limitations. [Package 28](implementation/prs/pr-28.md)
records the [remote readiness decision](architecture/decisions/0032-remote-mcp-readiness.md) and
[conditional setup/acceptance](development/remote-mcp.md) for review; remote activation is deferred.

Work package 29: [diagnostics/security audit](development/diagnostics-security-audit.md),
[ADR-0033](architecture/decisions/0033-diagnostics-support-report.md) and
[acceptance](implementation/prs/pr-29.md#implementation-and-acceptance).

Work package 30: [release engineering](development/release-engineering.md),
[account checklist](development/account-release-checklist.md), [release policy](releases.md) and
[ADR-0034](architecture/decisions/0034-release-engineering-readiness.md).

Work package 31: [ChatGPT distribution matrix/setup](development/chatgpt-distribution.md),
[ADR-0035](architecture/decisions/0035-chatgpt-distribution.md),
[acceptance](implementation/prs/pr-31.md#implementation-and-acceptance) and
[remaining activation work](implementation/activation-backlog.md). No installable plugin or
public release exists; completing the numbered sequence does not close live acceptance gates.

Native bridge follow-up: [brief/acceptance](implementation/prs/native-bridge.md),
[ADR-0036](architecture/decisions/0036-native-bridge-sample-pairing.md) and
[sample rehearsal](development/native-bridge.md). Fixed fixture pairing and XPC reads only;
signed external-helper and personal-provider activation remain closed.

Private Reminders testing: [six-slot finish line](../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line), [slot 1 brief](implementation/prs/private-reminders-slot-1.md), [ADR-0037](architecture/decisions/0037-external-helper-identity.md) and [account-free external helper checks](development/external-helper.md). This is the first-half checkpoint; see the completion path below.

Slot 1 completion: [ADR-0038](architecture/decisions/0038-private-native-mcp-relay.md) and [packaged native/MCP acceptance](development/private-native-bridge.md). Dedicated sandboxed sample app, local certificate identity and real stdio relay; no personal-provider activation.

Private selected Reminders: [slot 2](implementation/prs/private-reminders-slot-2.md), [ADR-0039](architecture/decisions/0039-private-selected-reminder-reads.md), [sample and isolated acceptance](development/private-selected-reminders.md).

Private approved sample writes: [slot 3](implementation/prs/private-reminders-slot-3.md), [ADR-0040](architecture/decisions/0040-private-approved-sample-writes.md), [native acceptance](development/private-sample-writes.md).

- [Private sample recovery](development/private-sample-recovery.md) — signed crash/relaunch and explicit fresh-session acceptance.
