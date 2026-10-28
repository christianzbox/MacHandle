# Reminders read checks

Read [ADR-0027](../architecture/decisions/0027-reminders-reads.md) and the
[acceptance ledger](../implementation/prs/pr-22.md#implementation-and-acceptance).
Use the pinned toolchain and the three standard repository gates with intended files staged.
Focused diagnosis: `swift test --filter 'Reminder|reminder'`.

The app adds Apple Reminders with access initially off. Enabling is an explicit TCC/discovery action;
no lists are selected automatically. Select at most 32 lists, search titles (empty query lists items),
and open details. Notes require the separate “Include notes when opening details” choice. Source
account labels help distinguish lists with identical names. Refresh/disable clears displayed content;
selection and query changes cancel pending reads. Local reads never grant access to an MCP client.

Do not click Enable or use real accounts during an automated unsigned UI check. Signed runtime tests
require maintainer-approved identity and explicitly authorized synthetic lists. Verify disabled launch,
permission denial/revocation, cancellation/late completion, list changes, exact detail lookup, date-only,
floating/named-zone due values, recurring/completed items, large-list partial coverage, sandbox and
minimum-OS behavior. Record scope and exact build separately; unit tests and SDK compilation do not
prove real provider behavior. Never reset TCC or change global toolchain configuration automatically.

The `machandle-mcp --synthetic` helper now advertises eleven tools. Its additional tools are
`list_reminder_lists`, `search_reminders` and `get_reminder`. Subprocess tests exercise both supported
protocol eras. [Official SDK smoke](../../Scripts/Interop/mcp_sdk_smoke.mjs) additionally verifies
legacy SDK 1.26.0 and client 2.4.0 pinned/auto. Use the existing documented SDK setup, outside Git;
no installed desktop client is reconfigured. Hidden notes, raw references and account names must not
leak into tool output or affect search matches. Forged/foreign handles and ungranted fields must fail.

Saved connection settings v2 retain independent read-only Reminder candidates. Legacy v1 creates no
new grants; restart never restores enabled peer authority. Actual signed helper/broker/native pairing
and OS observation remain required before exposing personal Reminder data. Calendar/Google access is
independent. No Reminder mutation tool, alarm editing, recurrence expansion or Notes support is added.
No fixture content, database, screenshot, credential or provider error belongs in Git.

## Scoped work-Mac UI evidence

Unsigned Debug inspection on 2026-10-28 verified the Apple Reminders navigation entry, its disabled
initial screen, explicit Enable button and disabled Refresh action. No Enable action was invoked and
no TCC prompt appeared. The preview was quit. This does not verify populated lists/details, real
permissions, signed runtime, full VoiceOver or another physical Mac. Debug and Release Info.plist
both contain NSRemindersFullAccessUsageDescription. Screenshots were not added to Git.
