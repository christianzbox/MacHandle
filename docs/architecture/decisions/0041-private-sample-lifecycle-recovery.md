# ADR-0041: Private sample session lifecycle and recovery

Date: 2026-10-30. Status: implemented for review; sample acceptance only.
Prerequisite: GitHub PR #37 merged at `69b5445c794f03eeb0d06acd12472aee97031239`.
Scope: [slot 4](../../implementation/prs/private-reminders-slot-4.md), following
[ADR-0040](0040-private-approved-sample-writes.md). Specification §4.7 and §8.3 own Reminder approval
and write safety; this does not activate the separate sync recovery requirements in §7.9.

## Decision

Provide native, content-free journal inspection without opening a connection or constructing a
provider. It opens the same installation-bound store from the sealed sample-writes configuration;
first use can create an empty store, while an existing store uses the unchanged strict resume path.
The view shows total applied/not-applied/unresolved counts and up to 20 operation UUID/status rows.
Unresolved rows sort first, then UUID; this is explicitly not a chronological activity log. There are
no reminder titles, targets, arguments or credentials in recovery storage. Inspection cannot alter
receipts, reset/prune the store, retry, approve or resolve an operation.

A durable applied receipt means the sample effect was accepted; notApplied means explicit nonacceptance.
Pending after interruption and unknown remain uncertain. They never become notApplied merely because
the client disconnected, a process restarted or the sample reminder is now absent. They continue to
block composition and every new dispatch through the existing journal guard. There is no truthful
reconciliation of an unknown in-memory effect after its process dies. The recovery outcome in that
case is explicit containment with retained evidence, not an invented success or a retry button.

## Shutdown and fresh sessions

Native stop closes transport/admission synchronously, changes the session generation, clears pending
native reviews and invalidates action authority. The mutation adapter counts admitted commits before
suspension; close waits for those commits, their actual journal receipts and native outcome delivery
to settle. A denied/lost wire reply is still distinct from the recorded provider effect. Concurrent
stop/quit callers await the same shutdown, and the native Quit button waits before terminating.

Force Quit, process kill, OS termination and a crash can interrupt that wait. SQLite's durable pending
intent then remains uncertain on reopen. No claim of graceful completion is made for those paths.
If accepted work never returns, ordinary stop waits; force termination preserves conservative restart
containment. No live provider is admitted, and this change adds no timeout that falsely reports rollback.

After completed shutdown, a user may explicitly prepare a fresh sample session only when current
journal evidence is readable and has no unresolved operation. This clears selection; enabling,
pairing and every exact write approval are required again. New composition means new opaque handles,
review/action tokens and in-memory sample contents. The same journal remains open and unchanged.
Callbacks capture the originating generation so an old listener, failed pairing, review or outcome
cannot close or authorize the new session. No silent reconnect or retained policy approval is added.

On process restart the signed app also starts with selection/access off. Inspection can display
receipts before any pairing. Rebuilding is not recovery: the acceptance harness deliberately crashes
and reopens the same signed package/installation, without editing/deleting its container or journal.

## Alternatives and consequences

- Automatically replaying interrupted work risks duplicates; preserve pending/unknown and stop.
- Clearing uncertain records or treating reset sample contents as evidence of nonacceptance would
  erase uncertainty. Keep the original records and live gate; no reset or operator override API.
- Terminating immediately on native Quit can lose a receipt after acceptance. Drain admitted work,
  while continuing to distinguish forced termination from orderly shutdown.
- Automatically reconnecting with prior selection/approval would extend old authority. Require a
  separate native fresh-session action and repeat selection/pairing/review.
- Persisting synthetic Reminder content solely to appear like a real provider would broaden this
  slot. Only operation evidence is durable; each fresh sample source is explicitly new.

## Verification and retained gates

Focused tests cover drain before/after provider acceptance, rejection after closure, reopened receipt
inspection without replay, old action/handle rejection, fresh pairing, immutable pending/unknown
reports and unsigned native refusal. Existing journal suites cover lost/mismatched receipts,
cancellation around effects, missing/corrupt/busy stores and pending after interrupted dispatch.

The [native recovery runbook](../../development/private-sample-recovery.md) tests actual signed
stdio/XPC/native approval, SIGKILL of the task-owned broker after one applied write plus an uncommitted
approval, same-package relaunch, recovery rows, helper disconnect and explicit fresh-session approval.
It does not time a real process kill inside SQLite/provider acceptance; deterministic suspended
provider tests cover that boundary. No fault-injection option is shipped in the signed app.

Real EventKit conflict semantics, isolated TCC/provider acceptance and minimum-OS runtime remain
engineering/maintainer gates. Revisit live recovery only after an accepted provider conflict contract
and separately authorized synthetic-only macOS test account. Personal iCloud stays excluded. Actual
client acceptance is slot 5; stable private identity/install/upgrade handoff is slot 6. No new slot,
paid account, public distribution or automatic follow-up is authorized.
