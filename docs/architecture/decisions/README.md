# Architecture decision records

| Record | Status | Decision boundary |
| --- | --- | --- |
| [0001 Native foundation](0001-foundation.md) | Accepted; toolchain superseded by 0002, deployment by 0004 | SwiftUI/Xcode + local SwiftPM, initial app target and development bundle identity, sandbox configuration, alternatives to project generation. |
| [0002 Interchangeable Macs](0002-portable-development.md) | Accepted | Exact shared toolchain, per-process selection, clean-clone evidence, GitHub handoff; runner availability and home-Mac verification limits. |
| [0003 Documentation authority](0003-documentation-authority.md) | Accepted | Complete source preservation, one execution plan, evidence/coordination split, focused context and post-merge updates. |
| [0004 Platform and Apple APIs](0004-platform-and-apple-apis.md) | PR-02 design; runtime gates open | macOS 14 API baseline, OS versus application permissions, recurrence/completeness and Contacts constraints. |
| [0005 Google desktop boundary](0005-google-desktop-boundary.md) | PR-02 design; live/console gates open | Desktop PKCE/loopback, method-by-method narrow scope audit, privacy and recovery blockers. |
| [0006 Local MCP and processes](0006-local-mcp-and-processes.md) | PR-02 design; signed IPC/pairing gates open | Stdio versions, broker authority, external-helper sandbox limits, peer identity and revocation. |
| [0007 Lifecycle, identity and distribution](0007-lifecycle-identity-and-distribution.md) | PR-02 strategy; production identity unallocated | Opt-in login, scheduling limits, Keychain identity/accessibility and Developer ID/notarization gates. |
| [0008 Core domain contracts](0008-core-domain-contracts.md) | Work package 03 merged in GitHub PR #4 | Typed identity/time/fields, explicit observation uncertainty, exact proposals and independent read/write interfaces; no runtime authority. |
| [0009 Permission policy engine](0009-permission-policy-engine.md) | Work package 04 merged in GitHub PR #5 | Trusted policy authority, narrow bound sessions, explicit resource/field grants, revocable decisions and filtered responses; no providers or approval issuance. |
| [0010 Native application foundation](0010-native-application-foundation.md) | Work package 05 merged in GitHub PR #6 | Explicit synthetic policy composition, observable preview state, native navigation/menu/Settings and close-versus-quit behavior. |
| [0011 Calendar authorization/discovery](0011-calendar-authorization-discovery.md) | Work package 06 implemented for review; live TCC gate open | Explicit opt-in, isolated EventKit actor, local inventory/selection, revocation and async-result invalidation; no event reads or writes. |

Read the records relevant to the active PR. No provider/authentication/persistence
architecture is considered decided merely because the product specification suggests
an approach. [Open decisions](../../../plans/MacHandleMasterImplementationPlan.md#unresolved-decisions-and-deferred-scope)
name the owner/gate for future ADRs.

New records should include date/status, context and evidence, the selected decision,
alternatives, tradeoffs, constraints, consequences, verification limits and links
to affected requirements/PRs. Record unresolved assumptions rather than inventing
support. Supersede explicitly; preserve earlier rationale in Git and linked records.
