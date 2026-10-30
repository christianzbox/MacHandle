# Private sample lifecycle and recovery acceptance

[Slot 4](../implementation/prs/private-reminders-slot-4.md) and
[ADR-0041](../architecture/decisions/0041-private-sample-lifecycle-recovery.md) define the boundary.
This uses in-memory reminders, a UUID/state journal and task-owned signing/launchd resources only.
No EventKit store, TCC request, personal iCloud, employer identity or actual desktop-client setup.

With the [pinned per-process toolchain](setup.md), build and run in a GUI session:

```sh
python3 Scripts/test_sample_recovery.py --bin-dir .build/out/Products/Debug \
  --interactive-native-approval
```

Follow native prompts within their deadlines. The script never clicks approval itself.

1. Select Sample list and enable, then approve the sample connection. Reads before pairing must fail.
2. Review/approve `Synthetic before crash`; the harness commits it once. The journal shows one applied.
3. Review/approve `Synthetic uncommitted at crash`. The harness kills only its exact UUID-named broker
   service before commit. The old helper must fail closed. The old approval is not a durable operation.
4. The same signed package relaunches. Confirm access off and selection unchecked. Inspect Sample
   Recovery: one applied, zero unresolved. Inspection must not enable access. Re-select, enable and
   pair anew. Both old action tokens and the old list handle must fail; no automatic replay occurs.
5. Approve `Synthetic uncommitted at disconnect`. The harness closes its helper without committing.
   Confirm Session stopped, one applied and zero unresolved. Prepare Fresh Sample Session must reset
   selection and keep Enable disabled until selection is repeated. Pair the next helper separately.
6. The disconnected approval/list handle must fail. Review/approve `Synthetic fresh approved session`;
   a new commit succeeds once and replay fails. Stop, inspect recovery and expand operation rows:
   two applied, zero unresolved, with two content-free operation UUIDs. Same-client reads must fail.
7. Return to clean up the exact temporary jobs, package, canary and signing keychain. Sample journal
   and OS-managed container remain. Never remove Library/iCloud containers or existing Keychain items.

## Interpreting recovery

| Evidence | Allowed next step |
| --- | --- |
| Applied | Effect was accepted in that old sample source; never replay it. |
| Not applied | Explicit nonacceptance. Any new action still needs fresh native review. |
| Pending / unknown | Uncertain; keep writes blocked and preserve evidence. Do not retry, delete or rebuild to bypass it. |
| Missing/busy/corrupt or unreadable journal | Fail closed; no replacement or reset of an existing store. |
| Readable journal with no uncertainty after orderly stop | Explicitly prepare a fresh session, re-select, pair and review new actions. |

Only operation status is durable. Fresh sessions reset synthetic Reminder contents. Their absence
cannot resolve uncertain historical operations. The view shows up to 20 UUID-sorted rows with unresolved
first, not chronology; counts include all records. Native Quit waits for accepted work. Force Quit,
crash or OS termination can interrupt it and leave pending evidence; no rollback is inferred.

Normal gates include deterministic before/after-effect drain, cancellation, lost/mismatched receipt,
pending/unknown restart and immutable recovery tests. The signed harness proves real process restart
following a persisted receipt and invalidates an uncommitted approval; it does not kill the process
inside the narrow effect/receipt window. Existing unit fault gates cover that uncertainty without
adding a production fault switch. Repeat the [six-operation sample workflow](private-sample-writes.md)
when mutation/approval code changes; retain read-only and external peer regressions as applicable.

This is safe sample recovery/containment, not a live provider reconciliation claim. Real EventKit,
minimum-OS runtime, actual desktop-client and stable identity/upgrade gates remain explicit. Two planned
slots remain; this procedure does not authorize starting them or using personal iCloud.
