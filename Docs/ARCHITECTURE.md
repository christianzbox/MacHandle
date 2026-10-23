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

## Planned boundaries

UI → application services → domain contracts. Provider, persistence, and transport
adapters implement domain interfaces. Domain logic must be independent of SwiftUI,
EventKit, Google JSON, MCP transport objects, and SQLite implementation details.

Create CoreDomain (PR-03), PermissionEngine (PR-04), and other packages only as
needed. The foundation metadata module can be folded into the application in PR-05
if it has no independent purpose; it is not a catch-all module for business logic.

Calendar read contracts and write contracts must be separate: synchronization
receives reads only. Operations always pass the trusted policy layer. Google sync
and MCP remain independent. A deterministic sync planner must precede remote
execution, using validated complete snapshots and durable mappings. All future
writes require applicable local approvals and conflict/revocation checks.

PR-02 must validate sandbox/helper boundaries and deployment requirements before
provider work. See [ADR-0001](ADR/0001-foundation.md) and the
[security model](SECURITY_MODEL.md). The full component list is planned in the
master specification, not implemented by this skeleton.
