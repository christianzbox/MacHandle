# ADR-0031: Notes feasibility and deferred activation

Date: 2026-10-29. Status: work package 26 decision merged in GitHub PR #27 at
`4450809877cc553bfebc7bfa051ac269884e3865`; package 27 availability follow-up merged in GitHub PR #28.
Documentation and installed public
terminology were inspected; no Notes runtime behavior was tested. Requirements: specification §11,
PR-26 and conditional PR-27. Extends [ADR-0004](0004-platform-and-apple-apis.md).

## Decision

Defer all live Notes capabilities, including reads. Keep Notes experimental/unavailable and prepare
package 27 as an explicit deferral and user-facing limitations package. This is **insufficient proof
to activate**, not evidence that a safe Notes integration is impossible. No provider, MCP tool,
Automation entitlement, permission request or script execution is introduced here.

The required sandboxed synthetic Notes proof of concept remains **unperformed and deferred**.
The user wants personal iCloud preserved and live testing later; no isolated authorized Notes test
environment or approved signing setup is established. An offline mock would not prove this gate.
Engineering owns the experiment; the maintainer owns isolated fixture/signing setup and authorization.
Revisit before any Notes activation once that environment is available, or earlier if Apple publishes
a materially different supported interface. Package 27 must retain this gate and cannot waive it.

## Supported interfaces and their limits

The [capability matrix](../../development/notes-feasibility.md#capability-matrix) records exact local
dictionary evidence, including inherited commands. Notes exposes account/folder/note IDs, HTML body,
plain text, lock/shared flags and attachment terminology. Those declarations establish an interface,
not a complete or permission-safe read, durable identity, lossless write or supported distribution.
No general public Notes CRUD framework was identified in this review; do not use private frameworks,
internal databases or implementation class names appearing inside the dictionary.

Apple's [sandbox documentation](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
requires App Sandbox for Mac App Store distribution. Its archived
[scripting-target guidance](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)
describes target-specific scripting groups. Notes' local suite declares `com.apple.Notes.openlocation`
on URL opening; its inherited Standard suite also has `*` group annotations on generic commands.
Neither observation proves that a selected-folder read/write policy can be enforced under a particular
entitlement. Do not infer broad CRUD permission from the URL group or generic annotations.
The [temporary-exception reference](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html)
documents target-specific Apple event exceptions when required groups are unavailable. That is a
candidate to evaluate with Apple, not a permission added here or an App Review approval guarantee.

The hardened-runtime [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events)
allows permission prompting, and [NSAppleEventsUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription)
explains that request. They do not substitute for sandbox authorization, native opt-in, selected
resources, connection policy or action approval. Signed sandbox/runtime proof, minimum/current OS
compatibility, notarization and any chosen store review remain separate acceptance gates.

## Alternatives considered

| Approach | Assessment and consequence |
| --- | --- |
| Fixed public Apple events through an internal provider | Candidate for the isolated experiment. Preserve sandbox; prove exact entitlement/consent behavior and selection before data retrieval. No arbitrary script, target bundle, selector or command supplied by MCP. Still unresolved. |
| User-installed AppleScript via NSUserAppleScriptTask | Apple's [documented API](https://developer.apple.com/documentation/foundation/nsuserapplescripttask) runs user-supplied scripts outside the caller's sandbox; a sandboxed caller can read, but cannot write, its application-scripts directory. This is a supported user-script model, not a way to install bundled automation or silently expand MacHandle's authority. Mutable scripts and broader execution authority need a distinct product/security review. Not selected as the default connector. |
| User-created Shortcuts | Apple documents [command-line execution](https://support.apple.com/en-mt/guide/shortcuts-mac/apd455c82f02/mac), which can pause for user input and returns process status. This does not establish structured Notes identity, exact mutation receipts, concurrency control or an immutable action definition. A caller-provided shortcut name cannot authorize an action. Unresolved; no shortcut was listed, installed, signed or run. |
| Unsandboxed helper, UI automation, private database/framework | Rejected for this integration: expands access or relies on unsupported internals, contrary to the product's supported-API/privacy constraints. Do not disable sandbox or request Accessibility/Full Disk Access as a workaround. |
| Defer activation with a reproducible acceptance plan | Selected. Preserves the Notes goal while accurately exposing missing proof and avoiding personal-account experiments. |

Shortcuts has its own [per-shortcut privacy approvals](https://support.apple.com/en-gb/guide/shortcuts-mac/apd961a4fc65/mac).
Those approvals must remain independent of MacHandle connection grants. No Apple/Google developer
credential or Google scope grants Notes authority. Existing Contacts `note` field restrictions are
unrelated to Notes.app access.

## Security contract for a future experiment

Start with bounded, selected-folder metadata and explicitly selected title/plain-text fields.
Names are display data, not identity. Bind account, folder, note and local provider generation; prove
membership before fetching content and recheck after suspension. Unresolved IDs, moves, account
changes, duplicate matches, incomplete results and cloud/offline uncertainty deny or return explicit
incompleteness. Absence never authorizes deletion. IDs are not cross-device synchronization keys.

Exclude locked/shared notes and unsupported content until isolation is demonstrated; never unlock
or follow links/attachment URLs automatically. Project authorized fields before search so hidden
content cannot affect matches or counts. Treat note text as untrusted data, never executable script,
instructions, HTML navigation or authority. Bound result count, bytes and execution time; sanitize
provider errors. Revoke and discard late results on disable, policy/OS change, cancellation or peer
loss. Content stays in memory, not logs, fixtures, diagnostics, Git or a general search index.

Writes need separate operation grants and exact trusted local approval. An HTML setter or modification
date is not an atomic compare-and-set contract. Before admitting a write subset, prove fidelity and
target continuity under simultaneous Notes/iCloud edits; a pre-read followed by a set leaves a race.
If that race cannot meet the requirement, defer the operation. Never flatten rich notes to plain text
and write them back. Any future dispatch requires durable intent, explicit unknown outcomes after
timeout/crash and read-only reconciliation; no automatic retry of create/delete or success inferred
from process exit. Whole-note deletion needs heightened review of all affected content, including
fields not otherwise exposed to the caller.

These are requirements for future code, **not implemented enforcement**. The
[isolated acceptance protocol](../../development/notes-feasibility.md#isolated-runtime-gate) owns the
next evidence. Passing current repository tests cannot establish Notes feasibility.

## Work package 27 availability follow-up

Deliver the explicit deferral path, without a Notes provider or simulated Notes connection. Overview
and Diagnostics share a static `NotesAvailabilityView`: experimental/unavailable status, reading and
editing unavailable until isolated testing, and no Notes access or permission request in this build.
The view has no state, task, callback, enable control or dependency on a provider. Existing Calendar,
Reminders and Contacts opt-ins remain separate. README/privacy/setup guidance uses the same boundary.

A dedicated empty Notes page or disabled Connect button would imply an actionable setup path where
none exists. A shared informational view keeps the explanation visible without that implication or
duplicate status copy. No new module, preference or capability flag is needed. Correct the adjacent
Diagnostics read/permission labels to include existing Reminders/Contacts opt-ins; this is copy only.

This completes package 27's availability/deferral deliverable, not the sandboxed Notes prototype or
any runtime capability. Engineering still owns G1–G6 and the maintainer owns isolated setup/signing
and authorization. Revisit on that evidence or a new supported public interface, through a reviewed
ADR amendment. Selected reads may be admitted separately from editing; no release or later remote
work may silently waive the gate. Validation is build/synthetic checks plus scoped native presentation
inspection; it cannot prove Automation, real Notes behavior, compatibility or distribution approval.
