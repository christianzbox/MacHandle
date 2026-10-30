# ADR-0028 — Approved Reminders management and durable containment

Date: 2026-10-28. Status: implemented for review in work package 23; live activation denied.
Requirements: [PR-23](../../product/master-spec.md#pr-23--authorized-reminders-management),
[§4](../../product/master-spec.md#4-security-and-permission-model),
[§9](../../product/master-spec.md#9-reminders-integration).
Builds on [Reminder reads](0027-reminders-reads.md), [approvals](0025-action-proposal-approval.md)
and [Calendar journal rationale](0026-calendar-mutation-journal.md).

## Decision and authority

Implement create, title/notes update, due-date change/clear, complete, uncomplete and delete as
independent typed operations. Uncomplete has its own permission; completing does not grant it.
Google remains denied. Saved Reminder candidates remain read-only v2: no migration expands writes.

A separate ReminderApprovalEngine binds a PolicySession and trusted current-authorization callback
(default deny). Existing-item preparation first obtains a scoped observation permit requiring the
operation, changed writable fields and title/due/completion/recurrence detail visibility; notes are
read only for a notes edit. Unknown revision is allowed only for that observation, never mutation.
The engine refetches the exact qualified target and binds its observed revision to a new proposal.
It independently evaluates mutation authority and projects provider over-return before making a
local review. Caller revisions, read handles, saved grants and policy permits do not become approval.

Reviews show exact account/list, identity context, before/after fields, due semantics, completion
state and single nonrecurring scope. Text is inert and bounded; control/format characters cannot
spoof the trusted display. Completion records its timestamp at execution; uncompletion explicitly
clears it. Unknown historic completion time is displayed as unknown. Delete needs separate local
acknowledgement. Reviews expire after 120 monotonic seconds and confirmations within 30 seconds,
are issuer-bound and single-use, and cannot cross Calendar/Reminder engines. Admission is serialized,
current policy/OS/selection and the projected observation are checked again before dispatch.
Revocation/expiry/cancellation before acceptance deny; acceptance is never described as rollback.
Unknown or mismatched receipts close the engine. Audit retains bounded operation UUIDs/phases only.

The local Connections screen offers six explicitly synthetic reviews using its own fixed sample
connection. It cannot select a real list. Native local reads retain their independent opt-in.
MCP adds propose_reminder_change and commit_reminder_change: only inert arguments and opaque action
IDs cross the wire. Confirm/review authority is an internal native-only API, absent from the tool
registry/schema. The standalone helper has no native confirmation channel; proposals stay pending
and commits return notApproved. Its sample-list/sample-reminder aliases belong to a separate fixed
synthetic writer fixture; read-tool handles cannot select that connection. Engine tests exercise a
trusted local confirmation followed by wire commit; this is not actual-client or signed IPC proof.
No production mutation adapter factory, writer or signed native bridge is exposed.

## Persistence and EventKit limits

ReminderMutations is a separate internal target; the MCP adapter imports approval contracts but no
EventKit, persistence or live writers. The independent ReminderMutationJournal reuses the hardened
SQLite primitive but has a distinct application ID and directory contract. Calendar stores are
rejected. It persists only random operation UUIDs and pending/applied/notApplied/unknown states,
with exact schema/installation checks, exclusive locking and owner-only files. Durable pending
intent precedes dispatch. Receipts are matched and persisted before success. Pending/unknown records
block new actions after restart; receipt-write failure returns unknown. No replay/reset/pruning API
exists; 4096 records is a fail-closed limit. No default production database is created.

The gated EventKit backend owns one lazy store, never prompts, and uses exact provider/store/source/
list/item identity, current writability, Reminder entity support, refresh and lastModifiedDate
observations. It resets cached state before observation, reads only requested fields and compares
again immediately before patch/save/remove. Calls commit immediately; no batching or Calendar span.
The modification-date token is a local observation, not a server version or atomic CAS. Apple exposes
separate refresh and save/remove APIs without a documented expected-revision transaction. Other apps
and cloud sync are not serialized by our actor, and timestamp granularity can miss changes. Therefore
mock atomicity does not establish EventKit conflict guarantees; live activation remains closed.
Success means local EventKit acceptance only, not cloud synchronization.

Due values preserve Gregorian civil date, date-only versus local time, and floating versus named
zone. Writers explicitly set Gregorian DateComponents as Apple requires. DST gaps/folds remain
components; no invented instant. Due dates never create/edit alarms. Completing sets isCompleted;
uncompleting clears completionDate. No caller-supplied completion timestamp is accepted.

## Explicitly retained scope and gates

| Capability / owner | Current result and reason | Revisit trigger |
| --- | --- | --- |
| Recurrence changes and completing/deleting recurring reminders — engineering | Deferred capability: all recurring/unknown-recurrence mutations denied, including completion; no occurrence identity or verified next-occurrence effects. No rule edits or series inference. | Isolated recurring-list fixtures establish supported effects and exact review scope before activation. |
| Alarm-bearing targets, alarm edits, list moves and broader metadata — engineering | Deferred capability: live backend rejects alarm-bearing targets; no implicit alarm/list/metadata edits. Domain due remains separate. | Isolated provider evidence, explicit field/operation contracts and reviewed UI before widening support. |
| Production writer and MCP native confirmation — engineering/maintainer | Closed factory; no runtime bypass flag. Missing approved signing identity, authenticated peer/native bridge, current OS/grant wiring and acceptable provider conflict contract. | Signed implementation and isolated acceptance with explicitly authorized synthetic real lists; user approval before real writes. |
| Unknown-result recovery and journal retention — engineering | Durable containment only; missing item/content equality is not proof of an operation. No automatic retry or reset. | Reviewed reconciliation/retention design preserving uncertainty and replay tombstones before live activation. |
| Minimum OS/home Mac/actual clients — maintainer | Not exercised by synthetic tests or unsigned work-Mac UI. | Appropriate hardware, approved identity and isolated fixture setup. |

These are explicit limits on package 23, not abandonment of product requirements or authorization
to begin a later package. [Package 24](../../implementation/prs/pr-24.md) is planned only.

## Alternatives and evidence

Rejected reusing Calendar approvals/journal identity, expanding saved read grants, trusting caller
confirmation or revision, guessing recurring completion effects, and using due dates as alarms.
Retaining distinct engines/types has some parallel code but makes the service boundary reviewable;
only shared inert rows/outcomes/audit and persistence primitives are reused. A local pre-save equality
check is useful stale-state detection but cannot justify claiming atomic external conflict handling.

Synthetic tests cover exact six-operation effects, independent fields/permissions, observation versus
mutation authority, target/OS/revocation changes, expiry/replay/foreign handles, no-op completion,
recurrence denial, due mapping, confirmation-only wire commits, cancellation around acceptance,
receipt loss and process restart. Negative compiler probes cover engine/confirmation/backend/adapter
access. Native builds and protocol/SDK checks are separate from signed/live acceptance; exact results
belong in [progress](../../implementation/progress.md) and the PR.

## Primary sources reviewed 2026-10-28

- [Creating events and reminders](https://developer.apple.com/documentation/eventkit/creating-events-and-reminders) — explicit user confirmation, reminder fields and completion behavior.
- [save Reminder](https://developer.apple.com/documentation/eventkit/ekeventstore/save(_:commit:)) and [remove Reminder](https://developer.apple.com/documentation/eventkit/ekeventstore/remove(_:commit:)) — immediate/batched commits, same-store objects, no documented expected-version argument.
- [refresh](https://developer.apple.com/documentation/eventkit/ekobject/refresh()) — merges unmodified properties and reports a deleted item; separate from dispatch.
- [dueDateComponents](https://developer.apple.com/documentation/eventkit/ekreminder/duedatecomponents) — Gregorian requirement, floating/date-only semantics; macOS does not require start date.
- [completionDate](https://developer.apple.com/documentation/eventkit/ekreminder/completiondate) and [isCompleted](https://developer.apple.com/documentation/eventkit/ekreminder/iscompleted) — clearing completion date uncompletes; external completion can lack a timestamp.

The signed native sample workflow is now composed by [ADR-0040](0040-private-approved-sample-writes.md). Its concrete fixture-only writer factory does not open the live EventKit factory or resolve the external conflict gate above.
