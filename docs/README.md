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
