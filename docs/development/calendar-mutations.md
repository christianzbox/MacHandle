# Calendar mutation adapter and recovery checks

Read [ADR-0026](../architecture/decisions/0026-calendar-mutation-journal.md) and the
[package 21 acceptance ledger](../implementation/prs/pr-21.md#implementation-and-acceptance).
The production factory denies. These instructions do not authorize a real calendar change.

## Automated evidence

Use the pinned toolchain and stage intended files, then run the three repository gates:

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

For focused diagnosis, `swift test --filter CalendarMutation` runs twelve adapter/scope and
four SQLite journal tests. The backend fixture verifies a durable pending intent exists before
effect; failure injection loses/mismatches receipts or closes the journal after acceptance.
Reopening must retain pending/unknown and block new operations. Preacceptance cancellation or
revocation must record nonacceptance; cancellation after acceptance must retain the accepted result.
No test initializes EventKit, requests TCC or inspects real source data. Existing synthetic approval
and policy tests cover field denials, stale proposals, deletion confirmation and Google isolation.

## Owned live acceptance follow-up

Engineering/maintainer must supply approved identity and explicitly authorize isolated synthetic
calendar setup before any live experiment. Do not bypass the factory to exercise personal calendars.
Complete signed peer/current OS/native grant and review wiring first; replace sample-only UI outcome
text for live composition. Use a new private journal directory bound to the installation and resume
it strictly. Never delete/recreate a journal to work around an uncertain outcome.

Record exact build/signed identity, OS/provider/calendar type and scope of each authorized experiment:

- Create/update/delete exact synthetic standalone events; preserve untouched fields and unrelated items.
- Revoke TCC/connection/selection/fields, make a calendar read-only or replace store/source identifiers.
- Edit/delete concurrently around refresh/save. Check Apple's recreation behavior explicitly; do not
  assert atomic conflict rejection without provider support. Keep affected writes disabled if unresolved.
- Exercise recurrence/detached/shifted instances, invitations, all-day DST and system-zone changes;
  unsupported scopes must reject rather than broaden. Current standalone-only policy is deliberate.
- Crash before/after dispatch and before receipt commit. Pending/unknown must block after reopen;
  absent records/events or matching content cannot prove ownership or safe retry. A reviewed recovery
  and retention procedure is required before activation; this package supplies containment only.
- Verify actual MCP clients, sandbox entitlements, minimum supported OS and accessibility. API compile
  proof, mock mutation tests and unsigned app builds do not establish any of these runtime properties.

No credentials, calendar content, database or screenshots belong in Git. Record redacted outcomes,
exact commits and remaining acceptance separately in the PR/progress ledger. Reminders reads in
package 22 remain independent of these write gates; Reminder mutations require their own semantics.
