# Contacts read checks

Read [ADR-0029](../architecture/decisions/0029-contacts-reads.md) and
[package 24 acceptance](../implementation/prs/pr-24.md#implementation-and-acceptance).
Use the pinned toolchain from [setup](setup.md), stage intended files and run:

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

The suite covers default-denied access/no implicit prompt; selected record/field fetches; identity,
move, notification and OS-revocation rejection; partial enumeration and missing detail; cancellation
and late results; minimal CNContact keys with unification disabled; bounded in-memory normalization;
native selection/field choices; settings migration; independent pairing and Google denial; opaque
handles, projection before search, hidden-field canaries, queued revocation and expiry. Four additional
negative compiler probes prevent external adapter/fixture/backend construction and writes via readers.

`Scripts/test_mcp_stdio.py` exercises the 16-tool synthetic inventory and Contacts discovery/search/
detail/denial/privacy with both wire profiles. `Scripts/Interop/mcp_sdk_smoke.mjs` repeats those checks
with the independently installed official legacy 1.26.0 and modern 2.4.0 clients (pinned and automatic
negotiation); use [MCP foundation instructions](mcp-foundation.md) for its external dependency setup.
No dependencies or generated fixture data belong in the repository.

Unsigned native UI inspection may open Overview and Contacts without pressing Enable. Confirm that
Contacts starts off, Refresh is disabled until explicit opt-in, and Calendar/Reminders/Google
remain independent. Optional detail-field behavior is covered by synthetic model tests; inspect its
live presentation only during the separately authorized fixture session. Quit afterward. This verifies presentation only;
do not request TCC, read personal contacts or claim signed/sandbox/runtime acceptance.

Engineering must separately obtain explicit authorization for an isolated fixture account and signed
app before testing OS permission grant/denial/revocation, linked contacts across selected/unselected
containers, membership moves and minimum-OS behavior. Actual MCP clients require signed peer/native
pairing/current-OS gates first. Contacts notes, persistent identity continuity and unified display
retain the owned triggers in the ADR. No source write or external listener is activated here.
