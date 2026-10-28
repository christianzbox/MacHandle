# Architecture

## Implemented in PR-01

The original minimal SwiftUI development window is expanded by work package 05 below.
`MacHandle.xcodeproj` builds the macOS application and links the local package in
`Package.swift`. `Sources/MacHandleFoundation` contains presentation metadata only.
`Tests/MacHandleFoundationTests` verifies package linkage and resource loading with
an explicitly synthetic fixture. It does not prove any provider or permission behavior.

The original app declared only App Sandbox, with hardened runtime enabled in build settings.
Work package 06 adds only the Calendar entitlement and full-access usage description
for explicit local discovery. There are no network entitlements, remote listeners,
credentials, telemetry or persistence. Unsigned CI builds verify
compilation; they do not prove runtime sandbox behavior or distribution readiness.

## Core domain — merged in GitHub PR #4

`Sources/CoreDomain` is a separate library target in the existing package. It holds
immutable Sendable resource identities, calendar occurrences/coverage/availability,
reminders, selected contact fields, typed changes/proposals and explicit errors/results.
`Tests/CoreDomainTests` exercises its public API with synthetic data.
`Scripts/check_domain_boundaries.sh` checks dependencies/imports and compiler rejection
of read-as-write access, wrong ID kinds and unified-contact deletion targets.

Domain imports only Foundation and has no target dependencies. CalendarReading and
CalendarWriting are separate async contracts; work package 07 implements reads only.
The app composes domain/policy libraries through the synthetic layer below; real
Calendar discovery has a separate adapter and explicit permission boundary.
[ADR-0008](decisions/0008-core-domain-contracts.md) records invariants, alternatives,
field/time/identity limits and owners of future behavior. Work package 03 merged at
`a990e05721e75770df98ba01c2bad2bc5aa731a7`.

## Permission engine — work package 04, merged in GitHub PR #5

`Sources/PermissionEngine` depends only on CoreDomain. PolicyRules are pure decisions;
PolicyAuthority serializes trusted configuration/OS observations, caller binding,
current decisions and response filtering. PolicySession exposes evaluation and
projection only. Immutable permits bind exact requests to one session and current
generations; policy/OS changes invalidate them. Every mutation still needs future
trusted local approval and provider precondition checks. No provider executes here.

[ADR-0009](decisions/0009-permission-policy-engine.md) defines the trusted composition
boundary and limitations. `Tests/PermissionEngineTests` uses synthetic public APIs;
compiler probes enforce narrow session access and dependency restrictions.

## Native application — work package 05, merged in GitHub PR #6

`Sources/MacHandleApplication` provides an observable presentation store and an
injected synthetic policy service. `App` contains SwiftUI navigation, Connections,
Activity, Diagnostics, Settings and menu-bar views. The composition root creates
private preview authorities; views cannot administer policy directly. Real OS
observations must never use these simulated authorities. Pending changes clear old
decisions; every enabled preview binds and revalidates under the current policy.
State is memory-only, starts disabled and records no real resource data.

[ADR-0010](decisions/0010-native-application-foundation.md) records trust boundaries,
alternatives, lifecycle choices, runtime evidence and limitations. The original package had no providers; work package 06 adds only the Calendar
discovery adapter below. Closing a window keeps the process alive; Quit terminates.
Menu actions target the single main window, with sync/login controls unavailable.

## Calendar discovery — work package 06, merged in GitHub PR #7

`Sources/AppleCalendarProvider` implements the CoreDomain metadata-only discovery
contract using actor-isolated EventKit. `CalendarAccessStore` is injected into the
application state separately from all sample policies. The Apple Calendars page
explains full OS access before opt-in, shows names grouped by local source, and keeps
selection empty by default. The store invalidates late/incomplete/revoked results
and refreshes on foreground and store-change notifications while enabled. Lifecycle
refreshes cannot prompt. Choices reset on quit and never become connection grants.

[ADR-0011](decisions/0011-calendar-authorization-discovery.md) records identity,
concurrency, storage tradeoffs and live verification limits. CalendarReading event
operations are implemented below; CalendarWriting remains package 21. No remote account
health or deletion completeness is inferred from local inventory.

## Calendar reads — work package 07, merged in GitHub PR #8

EventKitCalendarProvider implements CalendarReading with explicit selected calendars,
a 400-day request bound and a 10,000-occurrence limit. It exports normalized values,
never EventKit objects; revisions remain unknown and freshness is local-cache only.
CalendarReadStore owns a separate real PolicyAuthority, checks current OS status and
selection around suspension points, and filters the response before displaying it.
CalendarAccessStore invalidates read results synchronously when access/selection
changes. The local UI defaults to availability; titles/details require explicit mode
selection. Read results remain in memory, with no external consumer or writer.

[ADR-0012](decisions/0012-calendar-reads-availability.md) records field minimization,
recurrence anchors, civil-date/DST resolution, coverage uncertainty and live gates.
The app's Calendar entitlement is unchanged; its usage description now explains reads.

## Google authentication — work package 08, for review

GoogleAuthorization is an independent target with platform browser/network/crypto/
Keychain adapters, injected test seams and an actor that owns credential lifecycle.
GoogleConnectionModel exposes sanitized status/actions only. It never grants Apple
Calendar access, source writes, synchronization or MCP authority. Native Connections
shows a separate authentication section with Connect disabled in this build.

The composition has no configured Google service. No browser/listener/network/Keychain
operation starts, and application entitlements are unchanged. Live activation requires
confirmed app/credential identity, Google Desktop client/consent setup, a reviewed
network-entitlement/composition change and signed runtime proof. See
[ADR-0013](decisions/0013-google-oauth-keychain.md) and the
[setup checklist](../development/google-auth-setup.md). Synthetic callback tests exercise
an actual unsandboxed loopback listener; they are not signed-app or Google proof.

## Planned boundaries

UI → application services → domain contracts. Provider, persistence, and transport
adapters implement domain interfaces. Domain logic must be independent of SwiftUI,
EventKit, Google JSON, MCP transport objects, and SQLite implementation details.

CoreDomain, PermissionEngine, MacHandleApplication and AppleCalendarProvider have dedicated targets. Create
additional modules only as needed. Foundation remains presentation metadata only.

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
These remain researched designs except for the scoped Calendar discovery adapter
above. Only the justified Calendar entitlement is added; no helpers or listeners exist.
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

## Google destination client — work package 09, merged in GitHub PR #10

Internal components in GoogleAuthorization implement owned destination/event handles,
whitelisted payloads, conditional CRUD, bounded complete-or-error pagination and retries.
GoogleAuthentication supplies session-fenced requests and private bearer attachment;
no token getter or public destination factory exists. The app is unchanged and does
not construct the client. [ADR-0014](decisions/0014-google-destination-client.md) explains
why privacy, signed acceptance and durable identity must precede live activation.
No SQLite, planner/executor, source transfer, Calendar writes or MCP is introduced.

## SQLite persistence — work package 10, merged in GitHub PR #11

SyncPersistence uses the SDK SQLite library behind a single actor, explicit local
creation/resume, versioned transactions and bound metadata/operation/checkpoint values.
It has no domain/provider/UI dependencies. The app links it for universal build coverage
but never constructs it. Restored values require trusted remote verification and cannot
create Google capabilities. [ADR-0015](decisions/0015-sqlite-persistence.md) records
filesystem, backup, unknown-outcome and integration limits. No sync executor exists.

## Reconciliation planner — work package 11, merged in GitHub PR #12

SyncPlanning depends only on CoreDomain and SDK Foundation/CryptoKit. It compares
explicit snapshots, mappings and field policy to produce deterministic proposals,
conflicts and manual-intervention outcomes. Unknown/partial/stale state blocks writes;
absence from a bounded horizon alone never proposes deletion. Every deletion requires
confirmation. Availability projection clears details; fingerprints exclude hidden fields.
[ADR-0016](decisions/0016-pure-reconciliation-planner.md) records input trust boundaries,
identity/time conventions and integration gates. The app links but never invokes it;
no provider/storage adapter or executor is added.

## Synchronization executor — work package 12, merged in GitHub PR #13

SyncExecution coordinates the planner, SQLite store and a package-only owned Google
bridge through internal trusted authorization/observation injection. The default authority
denies all work. It persists identity before dispatch, verifies remote results, retains
partial/unknown outcomes and advances checkpoints only after successful reconciliation.
Read-only recovery verifies original operation IDs without replay. No Apple provider or
writer enters this module. The app links but cannot activate it; no live adapter exists.
[ADR-0017](decisions/0017-synchronization-executor.md) distinguishes synthetic integration
from remaining signed/privacy/freshness/writer and whole-process recovery gates.


## Recurrence and time — work package 13, merged in GitHub PR #14

EventKit continues to expand bounded selected reads; normalization rejects conflicting or
unknown occurrence anchors. Planning checks identity families against stored mappings and
exposes a pure local-day rolling horizon. Google timestamps must round-trip exactly;
all-day events retain civil dates and exclusive ends. Content-v2 fingerprints compare
exported instants/dates without display zones; legacy hashes conflict instead of silently
migrating. [ADR-0018](decisions/0018-recurrence-time-correctness.md) describes compatibility,
provider assumptions and synthetic normalization/planner/store/executor evidence.
No live composition, scheduling, account migration or source writing is enabled.

## Deletion safety and recovery — work package 14, merged in GitHub PR #15

SyncExecution requires default-deny approval of every entire destructive plan. Internal
recovery verifies complete owned inventories and exact baselines before atomic metadata
rebinds. SyncPersistence can import retained metadata into an empty replacement store;
GoogleAuthorization can restore authenticated standby capabilities and conditionally
transfer a cooperative writer generation. Remote IDs and creation history are preserved.
[ADR-0019](decisions/0019-deletion-safety-recovery.md) defines the trust boundary, race
handling and live limits; the [procedure](../development/sync-recovery.md) guides future
trusted composition. No new module, schema, scope or live activation is introduced.

## Background synchronization — work package 15, implemented for review

The internal SyncExecution coordinator owns one monotonic timer and one worker, debounces
source signals and invalidates its generation on changes/pause/sleep/offline/standby.
The scheduled job wraps existing trusted authority and refuses automatic pending-intent
replay. MacHandleApplication provides workspace/network hints and a Service Management
login model; only the explicit login control is composed into Settings. Live scheduling
and account/source/writer composition remain disabled pending package 16.
[ADR-0020](decisions/0020-background-synchronization.md) records behavior and live limits.

## Google onboarding — work package 16, implemented for review

CoreDomain contains local presentation/control contracts, MacHandleApplication owns an
observable model, and the native Connections screen replaces standalone sign-in with the
complete disabled/setup flow. Internal SyncExecution orchestration combines retained
reviews, selected lanes, existing durable execution and one background coordinator.
SyncPersistence v3 adds bound candidate preferences. The app injects no live service.
[ADR-0021](decisions/0021-google-sync-onboarding.md) and the
[activation ledger](../implementation/prs/pr-16.md#open-activation-follow-up--not-a-completed-milestone)
separate implementation from still-open milestone B acceptance. Package 17 is independent.

## MCP foundation — work package 17, implemented for review

MCPServer isolates protocol parsing, typed synthetic registry and stdio transport.
MacHandleMCP is a minimal executable requiring `--synthetic`. Neither depends on provider,
credential, policy, application or Google modules. No app embedding/broker/listener exists.
[ADR-0022](decisions/0022-mcp-server-foundation.md) specifies modern/legacy compatibility,
bounds, official SDK evidence and the signed packaging gate. The
[developer procedure](../development/mcp-foundation.md) uses disposable synthetic processes.

## MCP Calendar reads — work package 18, implemented for review

MCPCalendarAdapter depends on protocol/domain/policy contracts, with no Apple provider,
Google, credentials, persistence or UI dependency. Its internal service receives a bound
session and read-only provider; only the fixed synthetic factory is composed by the helper.
Four strict read tools project permitted data and use opaque reference handles.
See [ADR-0023](decisions/0023-mcp-calendar-reads.md). All executable data remains synthetic;
signed broker/identity/current-OS integration is required before live activation.
