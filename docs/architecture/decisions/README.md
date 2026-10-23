# Architecture decision records

| Record | Status | Decision boundary |
| --- | --- | --- |
| [0001 Native foundation](0001-foundation.md) | Accepted; initial toolchain selection superseded by 0002 | SwiftUI/Xcode + local SwiftPM, provisional app target and bundle identity, sandbox configuration, alternatives to project generation. |
| [0002 Interchangeable Macs](0002-portable-development.md) | Accepted | Exact shared toolchain, per-process selection, clean-clone evidence, GitHub handoff; runner availability and home-Mac verification limits. |
| [0003 Documentation authority](0003-documentation-authority.md) | Accepted | Complete source preservation, one execution plan, evidence/coordination split, focused context and post-merge updates. |

Read the records relevant to the active PR. No provider/authentication/persistence
architecture is considered decided merely because the product specification suggests
an approach. [Open decisions](../../../plans/MacHandleMasterImplementationPlan.md#unresolved-decisions-and-deferred-scope)
name the owner/gate for future ADRs.

New records should include date/status, context and evidence, the selected decision,
alternatives, tradeoffs, constraints, consequences, verification limits and links
to affected requirements/PRs. Record unresolved assumptions rather than inventing
support. Supersede explicitly; preserve earlier rationale in Git and linked records.
