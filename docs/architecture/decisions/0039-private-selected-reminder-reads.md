# ADR-0039: Native-selected private Reminders reads

Date: 2026-10-30. Status: implemented for review; sample runtime acceptance, real EventKit/TCC gate open.
Prerequisite: GitHub PR #35 merged at `8675999f309f2463b9c2f9ceda0d69a90f09e0ae`.
Requirements: specification §3.2, §4.1–4.2 and §13.4; [slot 2 brief](../../implementation/prs/private-reminders-slot-2.md).

## Decision and trust boundary

Add a separate MacHandlePrivateReminders executable for native list and field selection. Reuse the
slot 1 signed package, external MCP relay, native approval and read adapter. Preserve the original
MacHandlePrivateSample executable and its provider-free dependency graph. The new executable links
the existing public EventKitRemindersProvider, but a selected-sample launch injects synthetic records
and never constructs that provider. No mutation module is a dependency of the new app or relay.

The signed configuration binds three explicit profiles: legacy sample, selected sample and isolated
EventKit. The native entry point verifies the bundle/signature/profile before constructing a provider.
The relay accepts only the matching legacy/selected command family; no environment or MCP argument can
switch the native provider. The sample profiles have only App Sandbox. The isolated profile adds the
public calendars personal-information sandbox entitlement and Reminders full-access purpose string;
no Calendar permission request or Calendar read flow is composed. The helper stays unsandboxed with
no provider/policy/approval implementation, as documented in ADR-0038.

Everything starts disabled and unselected. Native opt-in alone may request Reminders permission;
list discovery requires full authorization and complete, unique bounded metadata. Select up to 32
lists and explicit fields (title, completion, due, recurrence presence, notes). No field is preselected.
Selection and per-launch native approval are separate. Starting the connection freezes its selection;
changing it requires stop/clear and relaunch with a new review. Notes need an explicit field choice.
The native display is untrusted resource text and cannot administer access.

An immutable SelectedReminderReader checks list/field bounds before the provider and observes actual
provider authorization before and after reads. It rejects incomplete/duplicate/missing selected-list
discovery and discards permission-revoked results. The existing MCP lease additionally checks identity,
current policy, field projection, cancellation and revocation before encoding/delivery. Initial reads,
foreign lists/opaque IDs, hidden fields and mutations remain denied. The read path never requests OS
permission. Store change notifications close the session and clear native selection; foregrounding
rechecks permission, and every read independently rechecks it. Late discovery cannot restore a stopped
session. This conservative close-on-change policy trades convenience for explicit review of a fresh
inventory; lifecycle/recovery refinements belong to slot 4.

## Account-free isolation and acceptance limits

Apple's public [requestFullAccessToReminders](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoreminders(completion:))
API grants read/write permission, not OS-enforced read-only access. The isolated package declares
[NSRemindersFullAccessUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremindersfullaccessusagedescription)
and the sandbox entitlement described in [Accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store).
Sources checked 2026-10-30. MacHandle restricts the exposed workflow to reads in trusted code.

A list name, checkbox, filtered query or synthetic item in a personal account is **not** isolation.
The isolated runner requires a separate explicit launch flag; the UI then requires acknowledgement
of a separate macOS test user with no personal/synced accounts before the permission button enables.
That acknowledgement is an operator prerequisite, not technical proof. Do not inspect personal accounts
or request permission to try to establish isolation on the current profile. No personal iCloud, TCC
prompt, EventKit store creation, existing personal Keychain item or live account was used in this PR's
verification. Signing uses only task-owned disposable local keys/keychains, as in slot 1.

Real EventKit access with that disposable identity, denial/grant/revocation prompts, and availability
of account-free local Reminder lists remain **unverified**. Engineering and maintainer own this gate;
revisit only after separate authorization and confirmation of an isolated account with synthetic data.
If the OS cannot provide local lists without an online account, stop and document the limitation; do
not create an account, use personal iCloud, change the privacy boundary or silently claim completion.
The [runbook](../../development/private-selected-reminders.md) records the pass/fail evidence needed.
This PR delivers the slot 2 implementation and sample tests, not full live acceptance of slot 2.

## Alternatives and consequences

- Testing a specially named list under personal iCloud would still grant broad underlying access; use
  injected fixtures now and a separately authorized OS account later.
- Adding EventKit to the existing provider-free sample executable would erase a useful independent
  boundary. Keep that target and add a separate composition target, sharing native models and broker.
- Automatically selecting all lists/default fields would surprise the user; require explicit choices.
- A permission/identity assertion from the helper would collapse independent controls; derive identity
  from code and read current authorization from the provider in trusted code.
- Persisting selections or silently reconnecting could reuse stale authority. Keep this slice in memory;
  durable identity/setup handoff is slot 6 and lifecycle work is slot 4. No additional PR count is assumed.

No paid Apple enrollment, employer identity, Google account, actual desktop-client setup, writes,
persistent service installation, merge or next slot is authorized here.
