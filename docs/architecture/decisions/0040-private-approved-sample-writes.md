# ADR-0040: Native-approved private sample Reminder writes

Date: 2026-10-30. Status: implemented for review; signed sample workflow verified, live writer closed.
Prerequisite: GitHub PR #36 merged at `4396d35fa138cfd4f860ac48b594e3cdcb7f62df`.
Requirements: specification §4.7 and §8.3; [slot 3 brief](../../implementation/prs/private-reminders-slot-3.md).

## Decision

Add a distinct sample-writes package/executable, MacHandlePrivateWrites, composed by NativeSampleWrites.
Keep the provider-free slot 1 sample app, slot 2 selected-read app, and all read-only package profiles.
The new target uses the existing ReminderApprovalEngine, ReminderMutationAdapter and durable
ReminderMutationJournal via JournaledReminderProvider. Its only writer factory accepts a concrete
SyntheticReminderActionProvider. The live EventKit factory remains unconditionally denied; no caller
boolean, CLI option, environment variable or signed isolated-read profile can activate it.

The immutable signed profile selects the new tool catalog and sample-only composition. Both peers
still derive identity from their own signing certificate/exact sibling identifiers and validate the
bundle seal. The app remains sandboxed with no provider permission entitlement or purpose string;
the relay stays provider/approval-free and unsandboxed as in ADR-0038. No private Apple API or network
listener is added. A synthetic external-file canary must remain sandbox-denied during acceptance.

The user first explicitly selects the fixed **Sample list** and enables the sample session. Native
per-launch approval then grants its five read fields and permits proposals, not executions. The
existing read adapter issues temporary opaque IDs; mutation target resolution uses that same adapter
and lease, rejects foreign/expired IDs and cannot accept a raw list/item identity. No sample-list alias
can select an unrelated writer. The native write policy is separately bound to the paired connection
identity and continuously checks the channel's liveness. Saved read grants are not expanded into writes.

## Exact approval and dispatch

The shared ReminderMCPContract now also holds mutation wire schemas/descriptions. MCP exposes propose
and commit only; native confirm/reject methods never appear on the wire. One proposal is pending at a
time in this private workflow. The native window displays the observed account/list/target and exact
before/after fields, kind and scope. Text remains inert; it cannot confer authority. Deletion requires
its own unchecked acknowledgement, reset for every new review. Reject does not dispatch.

A proposal is not approval. Native confirmation is single-use, bound to the exact engine/connection/
operation/observed snapshot, and expires within 30 seconds (the review itself within two minutes).
Only a later commit can execute it. Engine validation, authorization and exact state comparison run
again before dispatch, and the sample backend atomically compares the expected snapshot before
applying. Replay, stale revisions, wrong-launch IDs, extra authority fields and native rejection deny
execution. Closing a connection invalidates reviews; already accepted effects must still report their
actual result. Native UI preserves a concurrently delivered outcome instead of overwriting it with
an obsolete waiting-for-commit message.

The broker's default registry remains read-only. A package-internal, native-supplied tools factory runs
only after pairing; the optional close hook invalidates added authority. A close during asynchronous
factory creation prevents registry admission. The new sample composition is the only factory adding
mutation tools. This keeps the read bridge independent of mutation backends/storage, while allowing
one audited native composition to add the two bounded tools.

## Durable containment and limits

The app opens an owner-only journal inside its own sandbox Application Support directory, bound to a
UUID in sealed configuration. Reopening uses resume, never silently overwrites a missing/corrupt/busy
existing store, and validates schema/identity. It contains random operation UUIDs and fixed outcome
states only, not reminder content, target identifiers or proposed arguments. Durable pending intent
precedes dispatch and a matching receipt is stored before success. Pending/unknown records block new
sample compositions after restart. There is no reset, pruning, automatic retry or replay API.

Storage is not closed underneath in-flight accepted work on native stop. Sample reminders themselves
are in memory and reset on a new process; this PR proves durable **operation containment**, not durable
Reminder content or complete recovery. The same packaged identity can reopen its journal; rebuilding
creates a different fixture identity/store and is not recovery from uncertainty. Do not use a rebuild
as a workaround for an unresolved real operation. Full lifecycle/reconciliation is slot 4, and stable
private identity/upgrade handoff is slot 6. Test package/jobs/signing keys are removed; the UUID/state
journal and OS-managed sample container intentionally remain. No personal iCloud container is read or cleaned.

## Provider conflict decision and retained gates

For this slot's sample path, the actor-owned synthetic backend has atomic snapshot comparison and
no external writers. That satisfies the precondition contract for sample writes only. The existing
[EventKit conflict assessment](0028-reminders-management.md#persistence-and-eventkit-limits) remains:
local refresh/lastModifiedDate checks cannot establish atomic compare-and-swap across other apps or
cloud writers. No production conflict guarantee has been accepted or weakened here.

Real EventKit writes remain closed until engineering/maintainer explicitly accept a documented
provider conflict contract, separately authorize an isolated synthetic-only test account, and verify
current permission, writable-list and provider effects. Slot 2's TCC/local-list availability gate also
remains open. Those are retained gates, not permission to use personal iCloud or buy an Apple account.
Recurrence/alarm-bearing writes, list moves, bulk operations, actual desktop-client configuration and
public release remain outside this slice. No extra PR count is assumed.

## Alternatives and evidence

- Reusing standalone synthetic aliases would disconnect reads from reviewed targets; use bound opaque
  IDs from the same native read adapter and a single shared in-memory source instead.
- Auto-approving in an integration fixture would miss the trust boundary; the packaged test requires
  real native connection approval and exact review/acknowledgement clicks for every operation.
- Wiring a live backend just because it compiles would contradict unresolved conflict/permission gates;
  a concrete sample-only factory preserves that boundary and reuses the real journal/approval path.
- Putting writers/storage into the generic read bridge would expand older target graphs; a separate
  composition module owns them, with compiler/import/dependency guards retained.

Tests cover six effects, stale snapshots, rejected/foreign proposals, replay, revoke-before-commit,
reopened journal evidence, pending/unknown restart denial, and unsigned-app refusal. Existing engine
and journal tests retain expiry, cancellation around acceptance and lost receipt coverage. The
[native runbook](../../development/private-sample-writes.md) exercises actual signed stdio/XPC/native
review and verifies results through read tools. None proves EventKit, minimum-OS runtime or ChatGPT use.

Follow-up: [ADR-0041](0041-private-sample-lifecycle-recovery.md) implements sample shutdown/restart inspection and fresh sessions. It retains this live-provider gate and the rule that uncertain effects are never replayed/reset.
