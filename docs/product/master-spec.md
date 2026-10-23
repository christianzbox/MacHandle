# MacHandle
## Master Engineering Handoff & Incremental Development Plan

**Specification version:** 5.0  
**Date:** October 23, 2026  
**Project:** MacHandle  
**Product:** Native macOS personal information integration and management platform  
**Repository:** Existing user-created GitHub repository, intended name `machandle`  
**Visibility:** Public / open-source  
**License:** Apache-2.0, subject to verification of repository configuration  
**Primary language:** Swift  
**UI framework:** SwiftUI  
**Development methodology:** Focused, individually reviewed GitHub pull requests

---

# 1. YOUR ROLE

You are the principal software architect and engineer responsible for developing MacHandle.

You are expected to produce high-quality, secure, maintainable, production-ready software using native macOS technologies.

Responsibilities include architecture, implementation, testing, privacy, security, UI/UX, documentation, GitHub workflows, release engineering, and long-term maintainability.

**Critical instruction: Do not attempt to build the entire project in one session or pull request.**

This specification defines the overall product. Actual implementation must occur through the focused PR roadmap described below.

Each major PR should receive a fresh Codex session so the agent can work with the smallest useful context.

Always prioritize:

1. Data integrity and security
2. User control and privacy
3. Reliability and recoverability
4. Long-term maintainability
5. Correctness and comprehensive testing
6. Native macOS quality
7. Clean and efficient architecture
8. Good user experience
9. Minimal dependencies and infrastructure
10. Incremental, reviewable engineering

Never claim a feature is working without evidence from appropriate tests.

Never claim an external service is connected unless the connection actually succeeds.

Never claim a feature is secure merely because its source code is public.

---

# 2. PRODUCT VISION

MacHandle is a free, open-source macOS application that lets users securely connect, access, manage, and synchronize personal information from Apple's productivity ecosystem.

### Product description

**MacHandle — Your Apple essentials, connected and under your control.**

A privacy-first macOS app for connecting, managing, and syncing calendars, reminders, notes, and contacts across services. Users control what's shared, accessed, or modified. Also supports AI agents.

The application should be understandable to ordinary Mac users and useful to developers who want secure integrations with their existing applications.

MacHandle is not:

- A remote desktop application.
- A replacement for Apple Calendar or Reminders.
- An iCloud login client.
- An unrestricted Mac automation agent.
- A mandatory hosted cloud service.
- A system-cleaning or device-management utility.

It is a **personal information integration and management layer**.

## 2.1 Primary capabilities

MacHandle has three primary functional pillars.

### Manage

Allow authorized connections to:

- Discover selected resources.
- Read information.
- Search information.
- Create items.
- Modify items.
- Complete tasks.
- Delete items where explicitly permitted.

### Synchronize

Support controlled synchronization between compatible data sources and destinations.

Initial target:

Apple Calendar / iCloud → Google Calendar

Future destinations may include other calendar and productivity providers.

### Connect

Make authorized capabilities available to external applications, including:

- ChatGPT where supported
- Codex
- Other MCP clients
- Compatible automation software
- Future external integrations

These capabilities must work independently.

Google synchronization must not require enabling AI integration.

AI integration must not require connecting Google.

---

# 3. PRODUCT SCOPE

## 3.1 Apple Calendar — Core

Use EventKit.

Capabilities:

- Discover calendars.
- Select individual calendars.
- Check availability.
- Search events.
- Read event details.
- Create events.
- Update events.
- Delete events.
- Handle recurring events.
- Synchronize selected events to Google.

Calendar synchronization is an independent feature from direct AI calendar management.

## 3.2 Apple Reminders — Core expansion

Use EventKit.

Capabilities:

- Discover reminder lists.
- Select authorized lists.
- Search reminders.
- Read reminder details.
- Create reminders.
- Update reminder properties.
- Complete and uncomplete reminders.
- Delete reminders with authorization.
- Handle due dates and recurring reminders as supported.

Reminders must have independent permissions from Calendar.

Connecting Calendar must not automatically connect Reminders.

## 3.3 Apple Contacts — Core expansion

Use Apple's Contacts framework.

Capabilities:

- Search contacts.
- Read explicitly authorized contact fields.
- Create contacts.
- Update contact details.
- Delete contacts with explicit authorization.

Minimize fields fetched and returned.

Contact information is highly sensitive and must not be included automatically in synchronization or AI responses.

## 3.4 Apple Notes — Experimental integration

Investigate native macOS-supported automation mechanisms.

Apple Notes does not expose a general public Notes CRUD framework equivalent to EventKit or Contacts.

Potential approaches include:

- AppleScript
- User-installed Shortcuts
- Supported macOS Automation facilities

Do not use private Apple frameworks or directly manipulate the Notes database.

Do not bypass macOS security controls.

Do not assume Notes supports a fully reliable, granular, native third-party API.

Notes integration must have a separate feasibility and security milestone.

If a stable and appropriately permission-controlled Notes integration is not feasible, defer it rather than compromising the product's security.

Marketing must accurately describe Notes support as experimental until verified.

## 3.5 Future extensions

Design optional extension points for:

- User-selected iCloud Drive files and folders
- Photos using PhotoKit
- Additional calendar providers
- Additional task providers
- Microsoft 365 / Outlook
- Other standards-based integrations

These are not initial release commitments.

Do not grant broad Photos, filesystem, or Contacts access merely to prepare for future features.

---

# 4. SECURITY AND PERMISSION MODEL

Security is a foundational architectural requirement, not a feature added before release.

MacHandle will operate on sensitive personal information.

A bug or malicious update could expose appointments, contacts, notes, tasks, or other confidential information.

Design accordingly.

## 4.1 Permission layers

Maintain three independent levels of authorization.

### Level 1 — macOS authorization

Use native operating-system permission prompts.

Examples:

- Calendar access
- Reminders access
- Contacts access
- Notes Automation permission, if implemented
- User-selected filesystem access, if implemented later

Only request access when a user enables a feature requiring it.

### Level 2 — MacHandle connection policy

Each external connection has independent rules defining which data and operations it may access.

### Level 3 — Action approval

For sensitive modifications, require explicit user confirmation before executing the action.

An external service must not be able to authorize its own modifications simply by claiming the user approved them.

## 4.2 Important EventKit limitation

Apple's full EventKit calendar authorization allows reading and writing.

Apple's full Reminders authorization similarly allows reading and writing.

For calendars, write-only EventKit permission is possible in certain creation-oriented workflows, but it cannot read existing events.

Therefore:

**Application-level read-only access is not equivalent to an operating-system-enforced read-only capability.**

MacHandle must disclose this distinction.

When a connection is configured as read-only, MacHandle's trusted policy layer must reject all modifying operations.

The synchronization engine must not receive source-calendar write capabilities.

## 4.3 Permission vocabulary

Permissions should be resource-specific rather than using one unrestricted set of generic flags.

Common permissions:

- Discover
- Read summary
- Read details
- Create
- Update
- Delete

Additional domain operations:

- Check calendar availability
- Complete reminders
- Modify reminder due dates
- Search contacts
- Read selected contact fields
- Modify contact fields

A client authorized to create a calendar event is not automatically authorized to delete one.

A client authorized to search Contacts must not automatically receive all contact information.

## 4.4 Granular selections

Support user selection of:

- Calendar accounts and individual calendars
- Reminder lists
- Contact fields and supported subsets
- Notes accounts/folders where technically enforceable
- Individual destination integrations

Different connections may have different permissions for the same resource.

Example:

**Google Sync**

- Read availability from Personal calendar.
- Read no Contacts.
- Read no Notes.
- Modify no original calendar events.

**ChatGPT**

- Check availability in Personal calendar.
- Create events with confirmation.
- Search selected Reminder lists.
- No Notes access.
- No Contacts access.

**Local trusted automation**

- Read selected calendar details.
- Manage a designated reminder list.
- No access to unrelated resources.

## 4.5 Default authorization

All integrations are disabled by default.

Connecting a service must not silently connect all Apple data.

A new connection receives the minimum capabilities selected by the user.

AI connections should initially default to availability-only calendar reads and no write permissions.

No data is transmitted merely because the user installed MacHandle.

## 4.6 Runtime enforcement

Every operation must validate:

1. Connection authentication and identity.
2. Whether the connection is enabled.
3. Target resource ownership.
4. Resource selection.
5. Operation authorization.
6. Field-level visibility.
7. Approval policy.
8. Current revocation state.
9. Relevant item version or mutation preconditions.

The policy must be enforced within trusted application code, not merely within an AI prompt or tool description.

Revocation must prevent subsequent privileged operations.

Do not let clients select a higher-privileged identity by supplying arbitrary tool arguments.

## 4.7 Action approvals

Use propose-and-commit semantics for sensitive operations.

The application should:

1. Receive a proposed change.
2. Validate the connection and resource.
3. Compute the specific change.
4. Display a human-readable preview.
5. Require local confirmation if the configured policy requires it.
6. Execute exactly the approved operation.
7. Record a redacted audit entry.
8. Report actual success or failure.

Approvals should be bound to the operation, target, parameters, and requesting connection.

Use short-lived, single-use approvals where appropriate.

Deletion and bulk changes require elevated caution.

Never let AI-generated text masquerade as trusted approval.

## 4.8 Security invariants

These invariants are mandatory:

- Google synchronization never writes to original Apple Calendar events.
- External connections cannot bypass the policy engine.
- Secrets are never stored in plaintext configuration.
- Sensitive credentials never enter GitHub.
- Unauthorized resources never appear in tool responses.
- Revocation disables future access.
- Incomplete provider reads never trigger destructive reconciliation.
- No unauthenticated remote calendar endpoint exists.
- Events, reminders, contact fields, and notes are treated as untrusted input.
- No third-party cloud server operated by MacHandle receives user content by default.

Preserve these invariants throughout development.

---

# 5. TECHNOLOGY STACK

Prefer native, stable, long-supported macOS technology.

| Area | Preferred solution |
|---|---|
| Primary language | Current stable Swift |
| Application UI | SwiftUI |
| macOS integration | AppKit where needed |
| Calendars | EventKit |
| Reminders | EventKit |
| Contacts | Contacts framework |
| Notes | Separate feasibility assessment |
| Networking | URLSession |
| Concurrency | Swift structured concurrency |
| Authentication | OAuth 2.0 + PKCE where applicable |
| Secrets | macOS Keychain |
| Local persistence | SQLite |
| Logging | OSLog |
| Background behavior | Native macOS scheduling / Service Management |
| Local MCP | stdio |
| Remote MCP | Authenticated Streamable HTTP or supported secure tunnel |
| Testing | Swift Testing / XCTest / XCUITest |
| Dependencies | Swift Package Manager |
| Source control | Git |
| CI/CD | GitHub Actions |
| Release distribution | Signed and notarized macOS builds |

Avoid unnecessary:

- Electron
- Node.js runtimes
- Docker
- Python background daemons
- Hosted databases
- Firebase
- Supabase
- Custom cloud authentication services
- Analytics platforms
- Large dependency frameworks

An exception is permitted when a specific integration genuinely requires another technology and its benefits justify its security and maintenance costs.

Use the latest stable, supported APIs rather than experimental APIs simply because they are newer.

Choose a practical minimum macOS version after evaluating requirements.

Do not assume the current development machine's OS should automatically become the minimum deployment target.

---

# 6. HIGH-LEVEL ARCHITECTURE

Build a modular architecture that separates data providers, operations, authorization, integrations, and UI.

## 6.1 Core components

### Domain layer

Defines provider-independent types for:

- Resources
- Identities
- Calendars
- Calendar occurrences
- Reminders
- Contacts
- Permission policies
- Connection identities
- Proposed actions
- Sync mappings
- Errors
- Operation results

Avoid a giant generic data type that loses domain-specific correctness.

Use shared abstractions only when they actually reduce duplication.

### Provider layer

Encapsulates Apple APIs.

Initial modules:

- CalendarProvider
- ReminderProvider
- ContactsProvider

Potential separate experimental module:

- NotesProvider

Providers should be independently testable.

### Permission engine

Validates access for all connections.

This module should have no dependency on SwiftUI or model-generated instructions.

### Operations layer

Executes authorized reads and writes.

It must be separate from synchronization.

### Synchronization engine

Compares validated source state with destination state and safely reconciles differences.

### Integrations layer

Contains independent adapters for:

- Google Calendar
- MCP
- Future providers

### Application layer

Contains:

- Onboarding
- Menu bar
- Preferences
- Connections
- Permission editing
- Sync status
- Approval UI
- Diagnostics

## 6.2 Dependency direction

Prefer:

Application UI → Application Services → Domain Contracts

Infrastructure modules implement domain-defined interfaces.

Core domain logic must not depend directly on:

- SwiftUI
- EventKit
- Google JSON representations
- MCP transport objects
- SQLite implementation details

The synchronization planner and authorization policies should be testable in isolation.

## 6.3 Maintainability expectations

Use:

- Small cohesive modules
- Explicit interfaces
- Dependency injection
- Structured concurrency
- Immutable models where sensible
- Versioned persistence
- Deterministic tests
- Clear error models
- Architecture Decision Records

Avoid:

- Global mutable state
- Huge view models
- Unnecessary singletons
- Hidden network calls
- Circular dependencies
- Excessive protocol abstraction
- Giant catch-all utility classes

Prefer the simplest design that can safely support the required capabilities.

---

# 7. GOOGLE CALENDAR SYNCHRONIZATION

Google synchronization is optional.

It must operate independently of MCP and AI features.

## 7.1 User workflow

1. User installs MacHandle.
2. User grants Apple Calendar permission.
3. User selects source calendars.
4. User enables Google synchronization.
5. User authenticates with Google.
6. MacHandle creates a dedicated Google destination calendar.
7. User reviews privacy settings.
8. MacHandle previews the initial sync.
9. Synchronization begins after confirmation.

No iCloud credentials are required.

## 7.2 Destination model

Create an app-owned private secondary calendar, for example:

**MacHandle — Availability**

Do not use the user's primary Google calendar as the mirror.

Do not modify unrelated Google calendars.

Do not change Google calendar sharing settings.

Do not make the destination public.

## 7.3 Google permissions

Prefer:

`https://www.googleapis.com/auth/calendar.app.created`

Verify all needed Calendar API operations are supported with this scope.

Do not request broad Google Calendar account access unless a genuine product requirement makes it unavoidable.

Use a normal desktop OAuth flow with:

- System browser
- Authorization code
- PKCE
- State validation
- Supported redirects
- Secure token refresh
- Keychain storage
- Revocation handling

## 7.4 Public OAuth onboarding

Public MacHandle users should not need to create individual Google Cloud projects.

The published application should use a properly configured production OAuth desktop client.

Investigate Google's current:

- Consent-screen requirements
- Scope classifications
- Verification requirements
- Branding requirements
- Privacy policy requirements
- Refresh-token behavior
- API quotas

Do not ship a production build relying indefinitely on an OAuth application left in Testing status.

Do not embed confidential server credentials.

An OAuth desktop client identifier is not itself a secret or authentication guarantee.

## 7.5 Privacy modes

### Availability only — default

Transfer only information necessary to represent occupied time.

Use generic labels such as "Busy."

Do not include source event titles, descriptions, attendees, locations, meeting links, or private notes.

Preserve all-day and busy/free semantics.

Recognize that even occupied time ranges are sensitive information.

### Detailed synchronization — opt-in

Users may explicitly choose additional fields to mirror.

Never silently copy attendee lists.

Do not send invitations or guest notifications.

Switching to a more restrictive privacy setting should remove previously mirrored details.

## 7.6 Reconciliation requirements

The sync engine must handle:

- New events
- Modified events
- Deleted events
- Canceled events
- Recurring events
- Modified recurring instances
- Canceled recurring instances
- All-day events
- Multi-day events
- Timezone changes
- Daylight saving transitions
- Calendar moves and removals

The source remains authoritative.

Never propagate Google edits back to Apple Calendar as part of one-way synchronization.

## 7.7 Recurrence strategy

Investigate EventKit occurrence identity and recurrence semantics.

Prefer materializing occurrences inside a bounded horizon if that provides the strongest correctness guarantees.

Suggested initial horizon:

- 30 days into the past
- 365 days into the future

Document tradeoffs.

Do not rely solely on mutable start times as occurrence identifiers.

Avoid duplicate Google events after changes to recurrence rules or exceptions.

## 7.8 Deterministic reconciliation

Separate planning from execution.

The planner should generate:

- Create
- Update
- Delete
- No change
- Conflict
- Manual intervention required

A repeated sync against unchanged data should perform zero unnecessary remote writes.

Use deterministic fingerprints and stable mapping strategies.

Recover safely if the local mapping database is missing.

## 7.9 Safety and recovery

Never interpret these conditions as instructions to delete destination events:

- EventKit authorization revoked
- iCloud unavailable
- Incomplete source enumeration
- Network failures
- Calendar account temporarily missing
- Local database corruption

Protect against mass deletion.

Require confirmation for unusual destructive operations.

Recover from:

- Crashes
- Mac restarts
- Sleep/wake cycles
- Offline periods
- Rate limits
- Token expiration
- Partial remote writes
- Interrupted SQLite commits

A sync should be marked successful only when required reconciliation completes.

## 7.10 Multiple Macs

Support installation on multiple Macs.

Initially enforce or document a **single active synchronization writer per destination**.

Other installations may remain in standby.

Do not assume a local file lock protects the destination across different computers.

Provide a safe device transfer workflow.

Avoid duplicate events and conflicting writers.

---

# 8. MCP AND AI INTEGRATION

MCP must remain independent of Google synchronization.

The application should provide standardized, permission-controlled access to supported personal information.

## 8.1 Local MCP

Prioritize local MCP using stdio.

Compatible desktop and Codex clients may launch a local MCP process.

Keep the integration separate from the main SwiftUI interface.

Do not interpret stdio alone as proof of client identity.

Implement an appropriate local connection authorization or pairing mechanism.

Do not trust caller-supplied names or IDs as authentication.

## 8.2 MCP tools

Suggested Calendar tools:

- `list_calendars`
- `get_availability`
- `search_calendar_events`
- `get_calendar_event`
- `propose_create_calendar_event`
- `propose_update_calendar_event`
- `propose_delete_calendar_event`

Suggested Reminders tools:

- `list_reminder_lists`
- `search_reminders`
- `get_reminder`
- `propose_create_reminder`
- `propose_update_reminder`
- `propose_complete_reminder`
- `propose_delete_reminder`

Suggested Contacts tools:

- `search_contacts`
- `get_contact`
- `propose_create_contact`
- `propose_update_contact`
- `propose_delete_contact`

Notes tools depend on the feasibility milestone.

Every tool must use typed inputs, strict validation, a clear permission contract, and structured responses.

Do not expose unrestricted EventKit or Contacts framework methods.

## 8.3 MCP mutation safety

Write tools must use the trusted authorization policy.

Sensitive modifications should support propose-and-approve workflows.

Do not let an MCP client fabricate user approval.

Use conflict/version checking before overwriting existing information.

Require stronger confirmation for deletions, especially Contacts and Notes.

## 8.4 Prompt injection

Calendar descriptions, reminders, notes, and contact fields are untrusted data.

Never execute instructions embedded in user content.

Never interpret retrieved text as a new authorization policy.

A malicious event title or note must not be able to cause information disclosure or unauthorized modifications.

## 8.5 Remote MCP

Evaluate authenticated remote MCP using the current supported protocol.

Prefer supported private tunneling where practical.

Do not create a publicly exposed unauthenticated listener.

For any HTTP listener, evaluate:

- Authentication
- Authorization
- TLS
- Origin validation
- DNS rebinding protection
- Session and token lifetimes
- Rate limiting
- Revocation
- Network binding
- User identity isolation

Remote connectivity is optional.

No mandatory cloud backend should be introduced simply to make the local app work.

## 8.6 ChatGPT integration

Verify current ChatGPT MCP and plugin capabilities before implementation.

Do not assume:

- Every plan supports full MCP writes.
- ChatGPT can directly access arbitrary local stdio servers.
- A published plugin can directly control every user's Mac.
- Custom connections work inside recurring scheduled tasks.
- A Mac can answer remote requests while it is powered off.

Current platform capabilities and eligibility can change.

Implement local MCP first, then separately validate remote ChatGPT support.

## 8.7 Original hangout reminder use case

The original motivation was comparing personal calendar availability with a friend's work schedule and Detroit sports events.

MacHandle should enable that by making selected availability information accessible through Google or an authorized MCP connection.

However, the scheduled-task integration must be independently validated.

Do not present that end-to-end workflow as completed until tested.

---

# 9. REMINDERS INTEGRATION

Reminders must be an independent data provider.

Use EventKit and native authorization.

Support:

- List discovery
- Reminder discovery and filtering
- Reading reminder details
- Creating reminders
- Updating reminders
- Completing reminders
- Deleting reminders with confirmation

Handle due dates, completion dates, list changes, recurrence, and other supported metadata.

Preserve distinctions between due dates and notification/alarm behavior.

Do not synchronize reminder content to Google Calendar by default.

If Google Tasks synchronization is added later, it requires a separate adapter, authorization model, privacy review, and synchronization design.

Do not grant Google Tasks permissions for the calendar-only feature.

---

# 10. CONTACTS INTEGRATION

Use Contacts framework APIs.

Support selective reading and authorized modifications.

Minimize field access using appropriate property fetch keys.

Handle unified/linked contacts and contact identity carefully.

Avoid leaking the entire address book to AI clients when a request only needs one matching contact.

Support field-level policies where practical.

Never automatically export contacts to Google as a side effect of connecting Google Calendar.

Contact deletion and bulk modification require heightened safety controls.

---

# 11. NOTES INTEGRATION

Treat Apple Notes as a separately reviewed experimental feature.

Investigate public, supported macOS options and their limitations.

Potential challenges include:

- No general public Notes framework for arbitrary CRUD
- Automation permissions
- AppleScript compatibility
- Sandboxing and notarization
- Rich text preservation
- Attachments
- Checklists
- Locked notes
- Note identity
- Incomplete mutation APIs
- Potential data corruption

Do not modify Apple's internal Notes database directly.

Never use undocumented private frameworks.

Build a small sandboxed proof of concept using synthetic notes before making product commitments.

If read-only operations are feasible but editing is unsafe, ship only the safe subset.

If reliable integration is not possible, explicitly defer the feature.

Never claim support that has not been demonstrated.

---

# 12. NATIVE MACOS EXPERIENCE

MacHandle should feel like high-quality native Apple software.

## 12.1 Design direction

- Minimal
- Elegant
- Consistent spacing
- Native typography
- SF Symbols
- Thoughtful animations
- Light/dark mode
- Accessibility support
- Clear status indicators
- Responsive interface
- No unnecessary clutter

## 12.2 Menu bar

Provide:

- Current sync status
- Enabled connections
- Last successful synchronization
- Errors or warnings
- Sync Now
- Pause/Resume
- Preferences
- Manage Connections
- Activity History
- Diagnostics
- Quit

## 12.3 Onboarding

The initial flow should explain:

1. What MacHandle does.
2. Which Apple services users can enable.
3. Why macOS requests each permission.
4. Which external connections are optional.
5. How permissions are enforced.
6. Which information may leave the device.
7. How to revoke connections.
8. Which functions are supported versus experimental.

Users must not be required to connect Google to use local MCP.

Users must not be required to enable AI integration to use synchronization.

## 12.4 Connections interface

Every connection should show:

- Connection name
- Connected service
- Authentication status
- Allowed resource types
- Selected items/lists/calendars
- Allowed read operations
- Allowed write operations
- Required approvals
- Last activity
- Revoke/disconnect

## 12.5 Background behavior

Use supported macOS facilities.

Prefer a menu bar app with optional launch at login.

Automatically reconcile synchronization state while the Mac is running.

Use EventKit change notifications where appropriate.

Avoid busy polling.

Use bounded retries and avoid overlapping sync runs.

Do not require root permissions.

Do not claim continuous background operation while the Mac is shut down.

---

# 13. PUBLIC REPOSITORY SECURITY

The GitHub repository is public.

The user's personal information must never become public.

## 13.1 Prohibited repository content

Never commit:

- Real calendar events
- Personal reminders
- Personal notes
- Contacts
- Calendar exports
- OAuth tokens
- Authorization codes
- Confidential credentials
- Keychain exports
- Local SQLite databases
- Signing certificates
- Private keys
- Real diagnostic logs
- Sensitive screenshots
- Personal configuration files

Use synthetic fixtures.

A `.gitignore` alone is not sufficient security.

## 13.2 Credential handling

Use Keychain for sensitive credentials.

Avoid plaintext secrets.

Keep Google OAuth production and development configuration appropriately separated.

Do not bundle confidential server credentials into the public app.

Avoid developer-operated telemetry or collection services.

## 13.3 Repository protections

Maintain:

- Pull-request workflow
- Linear history
- Force-push protection on `main`
- Deletion protection on `main`
- Secret scanning
- Dependency auditing
- Appropriate CI checks
- Secure release workflows
- Least-privilege GitHub Actions permissions

Review every PR for unintended private data.

Never expose production signing credentials to untrusted pull-request workflows.

## 13.4 App sandboxing

Use macOS App Sandbox where compatible with validated functional requirements.

Investigate entitlements and any constraints arising from local MCP helpers, XPC, EventKit, Contacts, and Notes Automation.

Do not claim sandbox isolation protects resources it does not actually protect.

## 13.5 External security review

Before public write-enabled MCP functionality is released, conduct an independent security review.

Before a public download is distributed, test the full privacy and authorization model against synthetic accounts and resources.

Open-source availability improves auditability but is not a security guarantee.

---

# 14. GITHUB REPOSITORY STATE

The user has already been creating and configuring the MacHandle repository.

**Do not create another repository.**

Inspect the current checked-out repository and its GitHub remote before making changes.

Expected state based on the setup conversation:

- Public repository
- Working name: `machandle`
- Default branch: `main`
- README initialized
- Swift `.gitignore` selected
- Apache-2.0 license intended
- Squash merging enabled
- Merge commits disabled
- Rebase merging disabled
- Automatic head-branch deletion enabled
- Auto-merge disabled

The user has also prepared a branch ruleset targeting the default branch.

Intended ruleset configuration:

- Restrict deletions: On
- Block force pushes: On
- Require linear history: On
- Require pull requests: On
- Required approvals: 0
- Require conversation resolution: On
- No bypass actors
- Required status checks: Not yet enabled
- Signed commits: Not required initially

**Important:** These settings are expected, not guaranteed to have been saved. Inspect actual repository configuration when permissions allow. Do not overwrite working settings unnecessarily.

Do not disable protection merely to make automation easier.

Once CI exists, help configure required build, test, and security checks.

The user remains responsible for final PR review and merging.

A zero-approval rule does not technically require human approval; the no-auto-merge requirement must also be enforced by Codex's workflow instructions.

---

# 15. REPOSITORY STRUCTURE

Create a maintainable structure, adjusting only where Xcode or Swift Package Manager conventions justify it.

```text
machandle/
├── MacHandle.xcodeproj/
├── App/
│   ├── MacHandleApp.swift
│   ├── MenuBar/
│   ├── Onboarding/
│   ├── Connections/
│   ├── Preferences/
│   ├── Approvals/
│   └── Diagnostics/
├── Packages/
│   ├── CoreDomain/
│   ├── PermissionEngine/
│   ├── CalendarProvider/
│   ├── ReminderProvider/
│   ├── ContactsProvider/
│   ├── NotesProvider/
│   ├── GoogleCalendar/
│   ├── SyncEngine/
│   ├── MCPIntegration/
│   ├── Persistence/
│   └── Security/
├── Tests/
│   ├── Unit/
│   ├── Integration/
│   └── Fixtures/
├── UITests/
├── Scripts/
├── Docs/
│   ├── MASTER_SPEC.md
│   ├── ARCHITECTURE.md
│   ├── PR_PLAN.md
│   ├── CURRENT_STATE.md
│   ├── SECURITY_MODEL.md
│   ├── PRIVACY_MODEL.md
│   ├── TESTING.md
│   ├── RELEASES.md
│   ├── ADR/
│   └── PRs/
├── .github/
│   ├── workflows/
│   ├── ISSUE_TEMPLATE/
│   └── pull_request_template.md
├── AGENTS.md
├── README.md
├── CONTRIBUTING.md
├── SECURITY.md
├── PRIVACY.md
├── CHANGELOG.md
├── LICENSE
└── .gitignore
```

This is an architectural suggestion, not a requirement to create dozens of unused directories in PR-01.

Create modules incrementally as their implementations begin.

---

# 16. DOCUMENTATION STRATEGY

Documentation must preserve knowledge between Codex sessions.

This is essential because the application will be developed across many focused PRs.

## 16.1 AGENTS.md

Keep concise.

Must explain:

- Product purpose
- Architectural boundaries
- Core security invariants
- Coding conventions
- Build commands
- Test commands
- PR workflow
- Prohibited behavior
- Documentation locations

Do not duplicate the full master specification.

## 16.2 MASTER_SPEC.md

This consolidated handoff becomes the canonical master specification.

It defines the intended product.

When product decisions change, update the specification deliberately.

## 16.3 ARCHITECTURE.md

Describe the actual implementation.

Distinguish completed components from planned components.

## 16.4 PR_PLAN.md

Record each PR's:

- Number
- Title
- Dependencies
- Status
- GitHub PR link
- Merge commit where available
- Outstanding risks

## 16.5 CURRENT_STATE.md

Maintain a concise current-state summary containing:

- Implemented functionality
- Known limitations
- Current architecture
- Outstanding issues
- Recent decisions
- Next eligible PR
- Validation commands

## 16.6 Architecture Decision Records

Document significant technical decisions including:

- Why Swift
- Module boundaries
- Persistence strategy
- Event identity
- Sync reconciliation
- Google authorization
- MCP authentication
- Notes feasibility
- Multi-Mac behavior

Avoid unnecessary ADRs for routine implementation details.

---

# 17. DEVELOPMENT METHODOLOGY

This project must be developed through focused pull requests.

Do not implement everything at once.

## 17.1 One coherent change per PR

Every PR must have:

- A single primary objective
- Defined scope
- Defined exclusions
- Explicit prerequisites
- Relevant tests
- Security considerations
- Acceptance criteria
- Documentation updates

Prefer small, independently reviewable diffs.

If a PR becomes too large, propose splitting it.

Do not combine unrelated features because they happen to belong to the same overall milestone.

## 17.2 Fresh Codex context

Start a fresh Codex session for each significant PR.

For each session, read only:

1. AGENTS.md
2. CURRENT_STATE.md
3. The selected PR brief
4. Relevant architecture/ADR sections
5. Relevant source files
6. Relevant tests

Do not load all historical implementation discussions by default.

Do not repeatedly paste the master handoff into every session.

Use the repository as the durable source of truth.

## 17.3 PR lifecycle

For each PR:

1. Confirm prerequisites are merged.
2. Update local `main`.
3. Read the focused PR brief.
4. Inspect relevant code.
5. Create a feature branch.
6. Implement only the specified changes.
7. Add appropriate tests.
8. Run focused tests.
9. Run broader relevant checks.
10. Review privacy and security changes.
11. Update documentation.
12. Update PR_PLAN and CURRENT_STATE.
13. Commit coherent changes.
14. Push the feature branch.
15. Open a GitHub PR.
16. Report validation and limitations.
17. Stop for user review.

**Do not merge automatically.**

## 17.4 Standard PR brief

Each PR should have a brief with:

```markdown
# PR-XX — Title

## Objective
The single main result.

## Prerequisites
Required merged PRs or decisions.

## Context
Only the relevant architecture and constraints.

## In Scope
Work authorized for this PR.

## Out of Scope
Related work deliberately deferred.

## Contracts
Interfaces and invariants to preserve.

## Security
Threats and permissions relevant to this change.

## Implementation Notes
Important technical guidance.

## Tests
Required unit, integration, or UI checks.

## Acceptance Criteria
Observable completion conditions.

## Documentation
Files to update.

## Handoff
Information needed by the following PR.
```

---

# 18. COMPLETE INCREMENTAL PR ROADMAP

The initial roadmap contains **31 focused PRs**, divided into stages.

The exact number may change as the architecture is validated.

Do not combine PRs merely to reduce their count.

The roadmap defines work packages, not a mandate to implement everything in the first development cycle.

## STAGE A — PROJECT FOUNDATION

### PR-01 — Repository Foundation and Security

**Objective:** Establish the production-quality project skeleton.

Implement:

- Inspect existing repository.
- Preserve its existing README, license, and configuration.
- Initialize native Swift/Xcode project.
- Create AGENTS.md.
- Add master specification.
- Add PR roadmap.
- Create CURRENT_STATE.md.
- Add initial architecture documentation.
- Establish PR templates.
- Expand `.gitignore`.
- Add synthetic test fixtures.
- Add basic CI.
- Add secret scanning and privacy checks.
- Establish safe project conventions.

Out of scope:

- Apple permissions
- Calendar reads
- Google authentication
- Synchronization
- MCP

Acceptance:

- Skeleton builds.
- Tests/CI work where supported.
- No sensitive data is tracked.
- Repository remains public and appropriately protected.
- PR opens against existing `main`.

**Stop after opening PR-01.**

### PR-02 — Technical Feasibility and Architecture Decisions

Validate:

- Swift/macOS deployment targets
- EventKit behavior
- Reminders access
- Contacts framework capabilities
- Google OAuth and Calendar API scope
- MCP transport support
- App Sandbox feasibility
- Background operation strategy
- Code signing/notarization strategy

Produce focused ADRs and any small synthetic proofs of concept.

No full feature implementations.

### PR-03 — Core Resource and Domain Models

Implement:

- Resource identities
- Calendars/events
- Reminders
- Contacts
- Availability
- Operations
- Proposed changes
- Connection identifiers
- Provider errors

Use typed domain-specific structures rather than a universal unstructured object.

Add comprehensive unit tests.

### PR-04 — Permission Policy Engine

Implement:

- Connection policies
- Per-resource permissions
- Selected resource scopes
- Field-level visibility
- Read/write authorization
- Revocation
- Authorization decisions
- Denial reasons

Test privilege escalation and cross-connection isolation.

### PR-05 — Native Application Foundation

Implement:

- SwiftUI app shell
- Menu bar
- Preferences shell
- Connection-management shell
- Design system
- Light/dark mode
- Dependency composition
- Mock application states

No real personal data access yet.

---

## STAGE B — CALENDARS AND GOOGLE

### PR-06 — Calendar Authorization and Discovery

Implement EventKit authorization and calendar discovery.

Include:

- Permission prompts
- Source identification
- Calendar selection
- Access-denied handling
- Source unavailable handling

No event mutations.

### PR-07 — Calendar Reading and Availability

Implement:

- Time-bounded event reads
- Availability determination
- Event normalization
- Source snapshot validation
- Calendar filtering
- Safe error handling

Use synthetic test data.

### PR-08 — Google OAuth and Keychain

Implement:

- Desktop OAuth + PKCE
- Browser sign-in
- Token storage
- Refresh handling
- Revocation
- Disconnect
- Authentication tests

No event writes yet.

### PR-09 — Google Destination Client

Implement:

- Narrowly scoped Google API client
- App-created destination calendar
- Destination ownership checks
- Event create/read/update/delete primitives
- Pagination
- Rate-limit handling
- Structured errors

Do not modify unrelated Google calendars.

### PR-10 — SQLite Persistence

Implement:

- Database schema
- Versioned migrations
- Resource mappings
- Event mappings
- Fingerprints
- Sync state
- Pending operations
- Checkpoints

Test migration and corruption handling.

### PR-11 — Pure Reconciliation Planner

Implement deterministic desired-state comparison.

Inputs:

- Validated source snapshot
- Destination state
- Local mapping state
- Privacy configuration

Outputs:

- Create
- Update
- Delete
- No-op
- Conflict

Test determinism and idempotency.

No remote operations in this PR.

### PR-12 — Synchronization Executor

Implement:

- Ordered execution
- Checkpoint updates
- Partial failure handling
- Retry safety
- Remote success verification
- Recovery after interrupted writes

Never write to original EventKit calendars.

### PR-13 — Recurrence, All-Day, and Timezone Correctness

Implement and test:

- Recurring series
- Occurrence exceptions
- Cancellations
- Timezone changes
- DST transitions
- All-day boundaries
- Rolling sync horizon

Prioritize correctness over optimization.

### PR-14 — Deletion Safety and Recovery

Implement:

- Incomplete source protection
- Mass deletion safeguards
- Destination reconstruction
- Missing local mapping recovery
- Source account migration handling
- One-active-writer safeguards
- Standby-device behavior

Perform failure-injection tests.

### PR-15 — Background Synchronization

Implement:

- Launch at login
- Periodic reconciliation
- EventKit change notifications
- Debouncing
- Sleep/wake handling
- Network recovery
- Pause/resume
- No overlapping jobs

Measure idle resource usage.

### PR-16 — Google Sync Onboarding and Preferences

Implement the complete user-facing Google flow.

Include:

- Source selection
- Google authentication
- Privacy mode selection
- Initial sync preview
- Connection status
- Error messages
- Settings and disconnect controls

At this stage Google Calendar sync should be technically usable end to end.

---

## STAGE C — LOCAL MCP

### PR-17 — MCP Server Foundation

Implement:

- MCP stdio transport
- Protocol initialization
- Tool registration
- Typed schemas
- Structured errors
- Adapter architecture
- Mock tools

Do not expose live personal data initially.

### PR-18 — MCP Read Operations

Implement:

- Calendar discovery
- Calendar availability
- Event search
- Event detail reads

Integrate with the permission engine.

No source writes.

### PR-19 — MCP Connection Authentication and Revocation

Implement:

- Local connection identity
- Pairing/configuration where appropriate
- Permission persistence
- Revocation
- Session invalidation
- Unauthorized client rejection
- Audit metadata

Ensure caller-controlled names cannot confer privileges.

### PR-20 — Safe Action Proposal and Approval Engine

Implement:

- Create proposals
- Update proposals
- Delete proposals
- Validation
- Human-readable diffs
- Confirmation tokens
- Expiration
- Single-use enforcement
- Audit records

Use mock write providers.

### PR-21 — Authorized Calendar Mutations

Implement real EventKit event modifications behind the approved operations layer.

Support:

- Create
- Update
- Delete
- Target calendar validation
- Event version/conflict detection

Test with synthetic calendars.

Do not grant these operations to Google synchronization.

---

## STAGE D — REMINDERS

### PR-22 — Reminders Provider and Read Operations

Implement:

- Reminder authorization
- Reminder list discovery
- Reminder search
- Reminder details
- List selection
- Policy integration
- MCP read tools

Keep this separate from calendar synchronization.

### PR-23 — Authorized Reminders Management

Implement:

- Create reminders
- Update reminders
- Complete/uncomplete
- Delete
- Due-date and recurrence handling
- Approval integration
- MCP mutation tools

Test against synthetic reminder lists.

---

## STAGE E — CONTACTS AND NOTES

### PR-24 — Contacts Discovery and Read Operations

Implement:

- Contacts authorization
- Field-minimized fetching
- Contact search
- Contact detail access
- Per-connection policies
- MCP read tools

Respect account/container and unified-contact semantics.

### PR-25 — Authorized Contacts Management

Implement:

- Create contacts
- Update selected fields
- Delete contacts
- Approval workflow
- Conflict handling
- Audit metadata

Include heightened deletion safety.

### PR-26 — Apple Notes Feasibility and Security Review

Investigate:

- AppleScript
- macOS Automation permissions
- Supported Shortcuts integration
- Sandboxing
- Data fidelity
- Note identity
- Locked notes
- Attachments
- CRUD limitations

Build a synthetic proof of concept.

Document whether safe read and write capabilities are realistically supportable.

**This PR is a mandatory decision gate.**

### PR-27 — Optional Notes Integration

Proceed only if PR-26 establishes a sufficiently safe supported architecture.

Implement only verified capabilities.

If Notes integration is not practical, replace this PR with documentation and an explicit deferred-feature decision.

Never use private framework or database bypasses.

---

## STAGE F — REMOTE INTEGRATIONS, POLISH, AND RELEASE

### PR-28 — Remote MCP Compatibility and Secure Connection

Investigate and implement a practical secure remote integration path.

Include:

- Supported MCP transport
- Authentication
- Authorization
- Origin protection
- Private tunneling where suitable
- Remote revocation
- Mac offline behavior
- ChatGPT compatibility testing

Do not require hosted infrastructure for local functionality.

If secure remote use cannot be delivered without significant new infrastructure or unapproved platform support, defer activation.

### PR-29 — Diagnostics, UX Hardening, and Security Audit

Implement:

- Complete connection dashboard
- Sync diagnostics
- Audit history
- Redacted support export
- Accessibility improvements
- Error recovery UX
- Resource usage profiling
- Security review findings

Perform end-to-end testing of the actually supported services.

### PR-30 — Public Release Engineering

Implement:

- Developer ID signing workflow
- Notarization
- Hardened runtime
- Release packaging
- GitHub Releases
- Checksums
- Installation documentation
- Update policy
- Privacy policy
- Security policy
- Release validation

Do not announce a final public release until verification and required credentials are in place.

### PR-31 — ChatGPT Plugin Packaging and Distribution

Investigate and implement the supported plugin packaging strategy.

Document:

- Eligible ChatGPT plans and features
- Local versus remote capability
- Public plugin review
- MCP write limitations
- Permissions
- Setup steps
- Scheduled-task compatibility

Do not claim approval until actually approved.

This PR may be deferred if public plugin distribution remains blocked by external platform requirements.

---

# 19. RELEASE MILESTONES

The PR roadmap is not equivalent to a single release.

Use staged releases.

## Milestone A — Foundation

PR-01 to PR-07

Result:

- Secure public repository
- Native app shell
- Core policy engine
- Calendar reading

## Milestone B — Google Synchronization Alpha

PR-08 to PR-16

Result:

- Functioning Google calendar mirroring
- Reliable reconciliation
- Native onboarding
- Background sync

Test initially with synthetic data and isolated accounts.

## Milestone C — Local Calendar MCP Beta

PR-17 to PR-21

Result:

- Local MCP read access
- Per-connection authorization
- Controlled calendar write actions

Do not enable unsafe or incomplete write features.

## Milestone D — Personal Information Integrations

PR-22 to PR-27

Result:

- Reminders
- Contacts
- Notes if feasible

Each integration remains independently configurable.

## Milestone E — Public Distribution

PR-28 to PR-31, or a revised sequence based on readiness.

Result:

- Secure remote connectivity where feasible
- Polished application
- Audited permissions
- Signed and notarized releases
- Plugin packaging where supported

Do not force Notes or public plugin approval to block an otherwise safe, useful Calendar-and-Reminders release.

---

# 20. TESTING STRATEGY

Testing is mandatory from the beginning.

## 20.1 Unit tests

Cover:

- Resource identities
- Authorization decisions
- Field filtering
- Time intervals
- Recurrence
- Sync fingerprints
- Reconciliation plans
- Operation approval
- Revocation

## 20.2 Integration tests

Use mocked providers and synthetic fixtures for:

- EventKit reads and writes
- Google API calls
- OAuth state management
- SQLite persistence
- MCP requests
- Background operation lifecycle

## 20.3 Failure testing

Simulate:

- Permission revocation
- Source unavailable
- Network outage
- API rate limits
- OAuth expiration
- Interrupted writes
- Database corruption
- Multiple installations
- Stale resource identities
- Invalid approval tokens
- Concurrent operations

## 20.4 Privacy tests

Prove that:

- Availability-only mode excludes event details.
- Unauthorized calendars are filtered.
- Unauthorized reminder lists cannot be accessed.
- Contact fields are minimized.
- Disabled connections cannot execute tools.
- Revocation invalidates access.
- No tokens or personal details appear in logs.
- Sync failures do not modify source events.

## 20.5 Security testing

Include:

- Prompt-injection scenarios
- MCP client impersonation
- Replayed approvals
- Unauthorized mutations
- Cross-connection privilege escalation
- Malicious resource text
- Remote authentication failures
- Invalid request validation
- Supply-chain checks

## 20.6 Review requirements

Any PR affecting permissions, authentication, remote access, data deletion, synchronization identity, or release signing receives heightened security review.

Do not consider passing tests proof of total security.

---

# 21. CI/CD AND RELEASE SAFETY

Use GitHub Actions with least-privilege permissions.

Set up:

- Swift build
- Automated tests
- Formatting
- Static analysis
- Dependency checks
- Secret scanning
- Privacy checks
- Release packaging validation

Keep CI efficient.

Avoid duplicate jobs and unnecessarily expensive builds.

Pin external CI dependencies or actions to reviewed stable versions or immutable references where feasible.

Untrusted PRs must not receive production OAuth, signing, or release credentials.

Do not run tests against real private data in CI.

After PR-01 establishes stable check names, update the existing `main` ruleset to require the relevant checks.

Do not invent status-check names before workflows actually exist.

For public releases, use signed and notarized builds.

Do not instruct users to disable macOS security protections.

---

# 22. LONG-TERM MAINTENANCE

MacHandle is intended to be a long-lived open-source application.

Therefore:

- Avoid unnecessary dependencies.
- Document architectural decisions.
- Use stable Apple APIs.
- Maintain compatibility tests.
- Keep database migrations versioned.
- Preserve existing user configuration across updates.
- Preserve Keychain access where possible.
- Maintain clear release notes.
- Separate experimental integrations from stable core features.
- Monitor relevant API deprecations.
- Avoid cloud infrastructure that creates permanent operating costs.

Design the system so future contributors can understand one subsystem without learning the entire implementation.

Use semantic versioning and an explicit compatibility policy.

Do not enable new permissions automatically during upgrades.

New integrations require new explicit opt-in authorization.

---

# 23. CODEX CONTEXT MANAGEMENT

The project is deliberately structured to prevent context overload.

The master specification defines the full vision.

Individual PR briefs define implementation tasks.

A Codex session must not attempt to implement the entire master specification.

## Standard per-PR process

Before implementation, read:

- AGENTS.md
- CURRENT_STATE.md
- Current PR brief
- Relevant architecture sections
- Relevant ADRs
- Relevant source files and tests

Avoid reading the complete repository unless necessary.

After implementation:

- Update impacted documentation.
- Update CURRENT_STATE.md.
- Update PR_PLAN.md.
- Create or update the next relevant PR brief.
- Record test results.
- Record open risks.
- Open the PR.
- Stop.

The repository is the persistent context.

The previous Codex conversation should not be required to continue development.

---

# 24. REUSABLE PROMPT FOR FUTURE CODEX SESSIONS

After a PR merges, start a new Codex session with:

```text
Continue development of MacHandle.

Use the existing GitHub repository.

First read:
- AGENTS.md
- Docs/CURRENT_STATE.md
- Docs/PR_PLAN.md
- The next eligible PR brief
- Relevant architecture and ADR documents

Confirm the required prior PRs have merged.

Implement exactly one focused PR.

Preserve all existing security, privacy, data integrity,
and permission-model invariants.

Do not expand scope into unrelated roadmap items.

Add appropriate tests and run applicable checks.

Update current-state and PR-plan documentation.

Commit the implementation, push its feature branch,
and open a pull request targeting main.

Summarize what changed, what was tested, and any
remaining risks.

Leave the pull request open for my review.

Do not automatically merge it.
```

---

# 25. FINAL PRODUCT ACCEPTANCE CRITERIA

Before calling MacHandle production-ready, verify the relevant release's promised functionality.

### Core

- [ ] Normal macOS installation
- [ ] Native, polished interface
- [ ] No Apple ID password required
- [ ] Independent service connections
- [ ] Granular application-level permissions
- [ ] Connection revocation
- [ ] Safe approved write actions
- [ ] Minimal idle resource usage

### Calendar

- [ ] Calendar discovery
- [ ] Calendar reads
- [ ] Availability filtering
- [ ] Event creation/update/delete
- [ ] Recurring event correctness
- [ ] Reliable one-way Google synchronization
- [ ] Idempotent reconciliation
- [ ] Deletion safety
- [ ] Crash recovery

### Additional Apple services

- [ ] Reminders functionality appropriate to release scope
- [ ] Contacts functionality appropriate to release scope
- [ ] Notes supported only if feasibility is proven
- [ ] Independent authorization per service
- [ ] No unintended data export

### MCP

- [ ] Standards-compliant local tools
- [ ] Authorized connection identities
- [ ] Per-operation policy enforcement
- [ ] Safe mutation approvals
- [ ] Revocation
- [ ] Remote access only when authenticated and supported

### Security

- [ ] No credentials in GitHub
- [ ] No private test data
- [ ] No unauthorized calendar changes
- [ ] No unintended information disclosure
- [ ] Redacted logs
- [ ] Secure release pipeline
- [ ] Security review before public write-enabled release

### Open-source readiness

- [ ] Public repository
- [ ] Appropriate license
- [ ] Documentation
- [ ] AGENTS.md
- [ ] Reproducible build instructions
- [ ] Passing CI
- [ ] Safe, reviewable PR history
- [ ] Signed/notarized release when applicable
- [ ] Accurate feature documentation

---

# 26. OFFICIAL REFERENCE DOCUMENTATION

Verify current requirements before implementing each affected subsystem.

**Apple EventKit**  
https://developer.apple.com/documentation/eventkit

**EventKit access**  
https://developer.apple.com/documentation/eventkit/accessing-the-event-store

**Apple Contacts**  
https://developer.apple.com/documentation/contacts

**Apple Service Management**  
https://developer.apple.com/documentation/servicemanagement

**Apple Notarization**  
https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

**Google Calendar API**  
https://developers.google.com/workspace/calendar/api/guides/overview

**Google Calendar OAuth scopes**  
https://developers.google.com/workspace/calendar/api/auth

**Google Desktop OAuth**  
https://developers.google.com/identity/protocols/oauth2/native-app

**Google OAuth production readiness**  
https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance

**Model Context Protocol**  
https://modelcontextprotocol.io/specification

**OpenAI MCP documentation**  
https://developers.openai.com/api/docs/guides/tools-connectors-mcp

**OpenAI custom MCP connections**  
https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt

**Swift**  
https://www.swift.org/documentation/

**GitHub Actions**  
https://docs.github.com/en/actions

**GitHub rulesets**  
https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets

---

# 27. IMMEDIATE EXECUTION INSTRUCTIONS

## Begin with PR-01 only

The user has already created or initialized the GitHub repository and has been configuring its ruleset.

Do not create another repository.

Do not rename the existing repository.

Do not change its visibility.

Inspect the existing repository and remote first.

Determine:

- Swift version
- Xcode version
- macOS SDK
- Git status
- Repository branch
- GitHub remote
- GitHub CLI authentication
- Existing README/license/configuration
- Available GitHub ruleset information

Then implement **PR-01: Repository Foundation and Security**.

Specifically:

1. Create a focused feature branch from current main.
2. Set up the MacHandle Swift/Xcode project skeleton.
3. Preserve the existing repository initialization.
4. Add the master specification to the repository.
5. Add AGENTS.md.
6. Add ARCHITECTURE.md.
7. Add PR_PLAN.md.
8. Add CURRENT_STATE.md.
9. Create the initial focused PR briefs.
10. Expand `.gitignore` for sensitive local state.
11. Add security and privacy documentation.
12. Configure basic CI and test infrastructure.
13. Add appropriate secret scanning.
14. Verify no private material is tracked.
15. Run the available validation commands.
16. Commit the changes.
17. Push the feature branch.
18. Open PR-01 targeting main.
19. Report results, outstanding risks, and next steps.
20. **STOP.**

Do not implement EventKit, Google OAuth, synchronization, MCP, Reminders, Contacts, or Notes in PR-01.

Do not automatically merge PR-01.

The user will review and merge it before development proceeds.

---

# FINAL DIRECTIVE

Build MacHandle as a beautiful, secure, reliable, maintainable, privacy-first open-source macOS application.

The application will allow users to access, manage, and synchronize their Apple productivity information with external applications and AI assistants, while controlling which resources are accessible and what actions each connection may perform.

The platform must be modular, but not overengineered.

The permissions must be enforceable, not merely descriptive.

The synchronization engine must be safe and recoverable.

The public repository must never expose user data or confidential credentials.

Every development milestone must be independently testable and reviewed.

**Do not attempt to implement this entire project at once.**

Use the PR roadmap and focused context strategy.

Preserve the master vision in repository documentation.

**Start with PR-01, open the PR for review, and stop.**
