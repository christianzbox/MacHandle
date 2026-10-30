# Private sample Reminder writes acceptance

[Slot 3](../implementation/prs/private-reminders-slot-3.md) and
[ADR-0040](../architecture/decisions/0040-private-approved-sample-writes.md) own scope and decisions.
This procedure changes only in-memory synthetic reminders and writes UUID/state records inside the
new sample app's own sandbox. It never creates an EventKit store, requests TCC or touches personal iCloud.

## Run the sample workflow

Select the pinned per-process toolchain using [setup](setup.md), build, then run in a GUI session:

```sh
python3 Scripts/test_sample_writes.py --bin-dir .build/out/Products/Debug \
  --interactive-native-approval
```

The harness builds a separate `sample-writes` profile with a disposable local signing certificate in
a task-owned temporary keychain, then registers one temporary GUI-session job. It asks for actual
native actions, not a hidden test-approval endpoint. Follow each prompt promptly; reviews/approvals expire.

1. Confirm Sample list is initially unchecked, Enable disabled, journal unopened. Select the sample
   list and Enable Sample Changes. No OS permission prompt should appear. Unexpected prompt: stop.
2. The protocol probe starts; reads/proposals before connection approval must fail. Allow Sample
   Connection in the native window. This permits proposals, never automatic write execution.
3. Reject the first synthetic proposal. Its commit must return notApproved and journal count stay zero.
4. For each create, update, setDue, complete, uncomplete and delete, inspect account/list and exact
   before/after fields. Click Approve Exact Sample Change, then Return in the harness to commit once.
   Delete also requires the separate unchecked acknowledgement. Each preapproval commit and repeated
   commit must be denied. Extra approval fields/overlapping proposals are denied.
5. The client verifies each effect through the read tools, including completion changes and final
   absence of the created item. Verify the native journal reports six applied and zero unresolved.
6. Stop Sample Connection. The same client must lose access; Return lets the harness clean up its
   package, synthetic canary, disposable signing keychain and exact launchd job.

The external canary must be sandbox-denied. The UUID/state journal and OS-managed sample container
remain intentionally; do not delete Library/iCloud containers or existing Keychain items. The script
never changes desktop-client configuration. No Apple developer enrollment/employer certificate is used.

## Retained evidence and limits

The normal three gates run native composition tests with temporary synthetic SQLite stores: exact six
operation effects and reopened receipts; stale review after another fixture writer; revoked channel;
foreign/rejected proposal; pending/unknown journal restart refusal; unsigned app refusal before storage.
The existing approval/journal suites cover expiry, malformed reviews, cancellation before/after accepted
effects and lost receipts. Run the separate [slot 1](private-native-bridge.md),
[external peer](external-helper.md) and [slot 2 selected read](private-selected-reminders.md) regressions
on the final commit. They remain read-only; mutation tools appear only in the signed sample-writes mode.

No persistent reminder content is implemented: new processes reset the in-memory sample source while
the same packaged identity retains journal status. A new package gets a new fixture identity; that is
not a recovery/reset mechanism. Do not use rebuilding to claim an unresolved effect did not happen.
A failed/disconnected commit response does not prove no effect; preserve the journal and never resend automatically.
Sample lifecycle/recovery is covered by slot 4; unknown effects remain blocked without fabricated
reconciliation. Stable identity/install/upgrade handoff is slot 6.

The live EventKit mutation factory remains unconditionally denied. There is **no live-write command**
in this runbook. Engineering/maintainer must first resolve the documented external-writer conflict
contract and separately authorize an isolated account with synthetic local lists, then supply provider
acceptance evidence. Slot 2's TCC/account-free local-list gate is still open. No personal iCloud test,
minimum-OS runtime claim, actual ChatGPT integration or production readiness follows from this procedure.

Slot 4 now adds [sample lifecycle/recovery acceptance](private-sample-recovery.md). Historical operation status survives; unknown effects remain blocked rather than automatically reconciled.
