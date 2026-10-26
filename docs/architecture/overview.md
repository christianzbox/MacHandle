# Architecture

## Implemented in PR-01

`App/MacHandleApp.swift` is a minimal SwiftUI development window.
`MacHandle.xcodeproj` builds the macOS application and links the local package in
`Package.swift`. `Sources/MacHandleFoundation` contains presentation metadata only.
`Tests/MacHandleFoundationTests` verifies package linkage and resource loading with
an explicitly synthetic fixture. It does not prove any provider or permission behavior.

The app declares only App Sandbox, with hardened runtime enabled in build settings.
It has no personal-data usage descriptions, network entitlements, provider calls,
listeners, credentials, telemetry, or persistence. Unsigned CI builds verify
compilation; they do not prove runtime sandbox behavior or distribution readiness.

## Core domain — merged in GitHub PR #4

`Sources/CoreDomain` is a separate library target in the existing package. It holds
immutable Sendable resource identities, calendar occurrences/coverage/availability,
reminders, selected contact fields, typed changes/proposals and explicit errors/results.
`Tests/CoreDomainTests` exercises its public API with synthetic data.
`Scripts/check_domain_boundaries.sh` checks dependencies/imports and compiler rejection
of read-as-write access, wrong ID kinds and unified-contact deletion targets.

Domain imports only Foundation and has no target dependencies. CalendarReading and
CalendarWriting are separate async contracts; there are no real implementations.
The Xcode app still uses only MacHandleFoundation metadata, with no new permissions.
[ADR-0008](decisions/0008-core-domain-contracts.md) records invariants, alternatives,
field/time/identity limits and owners of future behavior. Work package 03 merged at
`a990e05721e75770df98ba01c2bad2bc5aa731a7`.

## Permission engine — work package 04, for review

`Sources/PermissionEngine` depends only on CoreDomain. PolicyRules are pure decisions;
PolicyAuthority serializes trusted configuration/OS observations, caller binding,
current decisions and response filtering. PolicySession exposes evaluation and
projection only. Immutable permits bind exact requests to one session and current
generations; policy/OS changes invalidate them. Every mutation still needs future
trusted local approval and provider precondition checks. No provider executes here.

[ADR-0009](decisions/0009-permission-policy-engine.md) defines the trusted composition
boundary and limitations. `Tests/PermissionEngineTests` uses synthetic public APIs;
compiler probes enforce narrow session access and dependency restrictions. The app
still links only foundation metadata; work package 05 owns application composition.

## Planned boundaries

UI → application services → domain contracts. Provider, persistence, and transport
adapters implement domain interfaces. Domain logic must be independent of SwiftUI,
EventKit, Google JSON, MCP transport objects, and SQLite implementation details.

CoreDomain and PermissionEngine now have dedicated targets. Create additional
modules only as needed. The foundation metadata module can be folded into the application in PR-05
if it has no independent purpose; it is not a catch-all module for business logic.

Calendar read contracts and write contracts must be separate: synchronization
receives reads only. Operations always pass the trusted policy layer. Google sync
and MCP remain independent. A deterministic sync planner must precede remote
execution, using validated complete snapshots and durable mappings. All future
writes require applicable local approvals and conflict/revocation checks.

PR-02's [platform decision](decisions/0004-platform-and-apple-apis.md) selects macOS
14 as the implementation baseline and defines provider identity/completeness limits.
The [Google decision](decisions/0005-google-desktop-boundary.md) selects desktop
PKCE/loopback and app-created scope, with privacy/recovery activation gates.
The [process decision](decisions/0006-local-mcp-and-processes.md) keeps a minimal
stdio adapter outside the trusted app-side broker; signed external-helper IPC and
pairing must be proven before live exposure. The
[lifecycle/identity decision](decisions/0007-lifecycle-identity-and-distribution.md)
chooses opt-in login, broker-owned credentials and Developer ID distribution gates.
These are researched designs, not implemented integrations. The sandbox is still
configured only for the foundation; no new entitlements, helpers or listeners exist.
See the [security model](security-model.md) and [PR-03 brief](../implementation/prs/pr-03.md)
for concrete domain consequences and the next authorized scope after merge.

## Shared development configuration

[ADR-0002](decisions/0002-portable-development.md) adds the user's PR-01 requirement that
work and home Macs are interchangeable. `Config/Toolchain.env` pins the compiler,
Xcode build, and SDK; scripts select/check tools per process. The checked-in project,
scheme, package, and formatter configuration contain no machine-specific paths.
Root AGENTS and `.codex/config.toml` provide shared Codex instructions/discovery;
GitHub PRs and versioned handoff documents carry progress between machines.
See [development setup](../development/setup.md). The original master-spec bytes remain
preserved; this supplements its development workflow without a competing roadmap.

## Durable engineering context

[ADR-0003](decisions/0003-documentation-authority.md) defines canonical document
ownership and focused reading routes. Product requirements remain complete in the
[specification](../product/master-spec.md); execution gates live in the
[master plan](../../plans/MacHandleMasterImplementationPlan.md). Actual verification
and merge facts are separate from planned architecture and active PR coordination.
