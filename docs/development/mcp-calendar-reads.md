# MCP Calendar read development checks

Work package 18 adds four policy-filtered read tools to the existing
`machandle-mcp --synthetic` helper. No Apple/Google account, key, Calendar permission or
installed client configuration is needed. Only an invented in-memory calendar/event is
exposed; there is no way to select a live connection through arguments or metadata.
See [ADR-0023](../architecture/decisions/0023-mcp-calendar-reads.md) for trust boundaries
and the [account setup guide](google-auth-setup.md) for future signing/Google prerequisites.

## Run checks

Use the pinned toolchain from [setup](setup.md), then from the repository root:

```sh
swift test --filter 'MCPServerTests|MCPCalendarAdapterTests'
swift build
python3 Scripts/test_mcp_stdio.py --executable "$(swift build --show-bin-path)/machandle-mcp"
```

Normal `Scripts/validate.sh` runs the Swift tests and all ten subprocess cases. The existing
[supplemental official SDK procedure](mcp-foundation.md#supplemental-official-sdk-interoperability)
now covers the mock tools plus discovery, availability, search, details and denied fields
in legacy SDK 1.26.0 and client 2.4.0 pinned-modern/auto modes. No npm runtime dependency
or personal client setting is added. Output schemas are validated independently by SDKs.

## Read sequence and limits

Use the protocol lifecycle/metadata appropriate to the chosen client, then:

1. Call `list_calendars` with `{}` and retain its opaque `calendarId`.
2. Call `get_availability` with `calendarIds: [calendarId]`, `startMs: 1799999000000`,
   `endMs: 1800004000000`. The fixed synthetic event falls inside this window.
3. Call `search_calendar_events` with the same window/selection and
   `query: "planning"`, `fields: ["title"]`, `limit: 10`. Retain the returned `eventId`.
4. Call `get_calendar_event` with that handle and `fields: ["location"]`.
   Requesting `notes` fails because the synthetic grant deliberately excludes it.

All argument keys are strict. `query: ""` and `fields: []` permit structural enumeration
without title content; a nonempty query requires title permission and fetched title values.
Search never examines location or notes. Details accept explicit title/location/notes
requests under their own operation/field grants; a search handle never grants detail access.
There are no mutation, sync-administration, permission or credential tools.

Windows are half-open; input timestamps are integer UTC epoch milliseconds. Returned
instant intervals/observations use epoch seconds, including fractional values; all-day
values preserve original civil dates, exclusive end and time zone. Source completeness
and freshness are independent. A locally complete result is not proof of upstream freshness,
`absenceProvesFree` is false, and missing detail is scoped to the original search window.

Read responses cap structured data at 16 KiB. Search limits are 1–100 rows; `truncated`
and partial coverage require a narrower window. Oversized availability/fields fail rather
than silently omitting busy periods or shortening content. Event handles expire after five
minutes, with at most 512 retained reference/window entries per adapter; calendars are
scoped to the process lifetime. Restart invalidates handles. These identifiers are opaque
names, not credentials, provider IDs, mutation revisions or portable cross-Mac references.

The helper still accepts only pipes/local stream sockets. No terminal listener, live
broker, account/permission request, storage or background installation is started.
Actual signed broker/peer checks and package 19 identity/revocation must pass before any
personal data is connected. Do not install this synthetic helper as a live integration.
