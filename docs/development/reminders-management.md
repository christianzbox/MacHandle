# Reminders management checks

Work package 23 uses synthetic data only. Read [ADR-0028](../architecture/decisions/0028-reminders-management.md)
and [acceptance](../implementation/prs/pr-23.md#implementation-and-acceptance).

With the pinned toolchain, stage intended files and run all three [standard gates](testing.md).
Focused development checks may use `swift test --filter 'Reminder|reminder|sampleReminder'`.
These include independent policy/approval, exact-state/field checks, six mutation effects, due
components, revoked/expired/foreign confirmation, journal durability and uncertainty on restart.
Calendar-to-Reminder journal substitution must fail. Tests use temporary private SQLite stores,
fixed in-memory Reminder data and no real EKReminder objects, permissions or personal accounts.

The synthetic helper has thirteen tools. `propose_reminder_change` accepts operation create, update,
setDue, complete, uncomplete or delete; uses sample-list for create and sample-reminder otherwise.
Create requires title; update accepts title/notes; setDue requires dueDate (empty clears). An optional
HH:mm:ss dueTime makes a local civil time; absent timeZone is floating. Date-only cannot specify a zone.
Unknown/mixed fields and caller approval flags are rejected. Its separate sample connection is not
addressable through read-tool handles. `commit_reminder_change` requires actionId but this alone is
not approval: the standalone helper has no native reviewer, so proposals cannot execute. Direct
adapter tests exercise the separate local-confirmation method; no wire tool can invoke it.

`Scripts/Interop/mcp_sdk_smoke.mjs` checks both pinned SDK generations and automatic negotiation,
including proposal schemas and rejection of an unapproved commit. Run it using the external temporary
SDK setup from [MCP interoperability](mcp-foundation.md) if available; do not add node_modules to Git.

For native review inspect Connections → Sample Reminder approval. All six samples use fixed data;
delete needs its checkbox, cancel discards the review, and success says no real Reminder changed.
Do not enable Reminders or perform real writes as part of this check. Ordinary local reads remain
independent. No signed TCC/sandbox/minimum-OS/live-provider proof follows from an unsigned UI preview.

Before live activation, engineering must resolve the provider conflict contract, signed identity/
peer/native confirmation/current OS/grants, isolated real-list tests, recurring/alarm effects and
reviewed uncertainty recovery. No retry/reset/environment switch bypasses these gates.
