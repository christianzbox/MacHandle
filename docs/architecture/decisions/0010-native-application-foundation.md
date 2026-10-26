# ADR-0010 — Native application composition and preview lifecycle

Date: 2026-10-26. Status: implemented for work package 05 review, not merged.
Requirements: specification §§6, 12, 20 and legacy PR-05. Predecessor GitHub PR #5
merged at `0cdac4bd5845b2b167a48c00332ef5ddf5080606` before this branch began.

## Context and decision

The policy library needs a native host without implying that an Apple provider,
Google account or MCP client exists. The app composition root explicitly constructs
two synthetic PolicyAuthority actors, a PreviewPolicyService and observable state.
Views receive presentation state and preview actions, never an authority or permit.
MacHandleApplication depends only on CoreDomain and PermissionEngine, plus Foundation
and Observation imports. SwiftUI/AppKit remain in App. The small existing foundation
metadata target is retained; unrelated module consolidation adds no value here.

Each sample has its own simulated OS context so choosing a denied sample cannot
change the other sample. These authorities must never be reused for a live provider.
The preview service replaces policy, binds a fresh session and revalidates an exact
read receipt before displaying an allow. There are no writes or local approval
issuers. A result means only a synthetic policy decision, not connection authentication,
OS authorization, data access or successful synchronization.

The main-actor store serializes changes, removes the previous result before awaiting
policy evaluation, and rejects overlapping updates. The actor also rejects overlapping
evaluations. Controls disable during evaluation. Revocation/configuration changes
invalidate prior policy receipts. History is bounded to 20 synthetic transitions;
configuration, history and appearance reset when the process exits. No persistence,
provider, permission prompt, credential, network or login registration is added.

## Native presentation and lifecycle

Use a NavigationSplitView with Overview, Connections, Activity and Diagnostics,
native controls, system typography/materials, text-plus-symbol status badges, and
system/light/dark appearance. Cmd-1 through Cmd-4 navigate; Cmd-comma opens Settings.
The connection screen exposes explicitly named preview states and selected sample
calendars; an empty selection grants nothing. Every page avoids implying live health.
Settings explains preview lifetime and leaves future launch-at-login unavailable.

A single Window scene and MenuBarExtra share the same state. Closing the window keeps
the process/menu item alive; Quit exits. Menu actions open the named main window.
Sync Now/Pause Sync remain disabled and the menu reports no live connections and no
successful sync. No work runs merely because the process remains open. Work package
15 still owns opt-in login registration and background scheduling.

## Alternatives and consequences

- A global singleton/service locator would hide authority ownership and complicate
  deterministic tests. Explicit construction costs a little plumbing but makes the
  trust boundary reviewable.
- UI-only canned allows would not exercise current policy. The synthetic adapter
  uses the real engine while keeping simulated OS observations isolated from future
  live services. Future providers require a separate trusted composition.
- Persisting preview choices could confuse samples with real grants. In-memory state
  makes restarts safe and deterministic; persistent preferences belong with a later
  deliberate storage decision.
- A custom web shell/design system would add dependencies and accessibility work.
  Native controls retain platform semantics, keyboard behavior and adaptive colors.
- Terminating on close would conflict with a menu-bar utility. Keeping the process
  alive is intentional, disclosed in Settings, and distinct from background sync.

## Verification and remaining gates

Eight application tests exercise disabled startup/no eager evaluator calls, clearing
old results during suspension, overlapping-update rejection, all six sample states,
empty selection, old-receipt invalidation/new binding, connection isolation under
simulated OS denial, write rejection, bounded history, and navigation without grants.
They supplement 40 existing Swift tests and 13 Python repository tests.

On the work Mac, a default locally signed universal Debug build launched. Native UI
inspection checked accessible names/roles, Cmd-1/2/3/4, Cmd-comma, empty-selection
denial, selected-calendar allow, revoke/activity feedback, and system-light/dark
presentation. Window close left the process running; Quit terminated it. The native
menu-bar extra's click/reopen path still needs direct human verification: the current
UI automation surface exposes the main app menu, not that status item. No VoiceOver
spoken-output, increased-contrast, oldest-OS, home-Mac, distribution signing, live
permissions, sandbox enforcement or integration guarantees follow from these checks.
See [progress](../../implementation/progress.md) for exact snapshot/gate evidence.
Work package 29 owns the broader accessibility audit; package 30 owns release/OS
coverage. Direct menu-item confirmation remains a work package 05 review check.
