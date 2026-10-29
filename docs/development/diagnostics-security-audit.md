# Work package 29 diagnostics and security review

## Scope and read-only first pass

Review the implemented native opt-in reads, synthetic MCP/approval paths and gated sync libraries.
This is an engineering review, not independent certification or live end-to-end acceptance.
Personal iCloud, TCC databases, Keychain contents and real client configurations are excluded.

| Track | Inspect and evidence | Risk / execution order |
| --- | --- | --- |
| Diagnostics privacy | Application stores, UI copy, raw-error/log searches; export input/output review | High if content or credentials escape; first |
| Authorization | Policy sessions, connection lifecycle, approval consumption and provider rechecks; existing negative tests | High if authority survives revoke; second |
| Recovery/persistence | Durable unknown outcomes, restore defaults and cancellation; failure tests | High if an uncertain write is retried; third |
| UX/lifecycle | Default composition, status/recovery controls, keyboard/AX inspection, bounded idle resource sample | Medium if unavailable capability appears active; fourth |
| Supply chain | Pinned toolchain/workflow, indexed privacy and history/index scanner | Required final gates |

Read-first findings: Diagnostics uses static credential/background claims instead of observed model
state; Activity's “No live actions have run” is broader than its sample-only history. Replace those
claims in this package. Existing diagnostics has no safe support export. Implement a closed-schema
report rather than collecting raw data and attempting to redact it. No raw-error logging was found
by the scoped App/Sources search for print, localizedDescription, fatalError, Logger or os_log.

One PR covers these related presentation/privacy fixes and their tests. No provider, permission,
authentication, remote activation, mutation retry or persistence rewrite is planned. Follow with
repository gates and native disabled-state inspection; signed/provider acceptance remains separate.

## Findings and disposition

| ID / severity | Evidence and disposition | Owner / remaining trigger |
| --- | --- | --- |
| D1 / medium | Static “Credentials: None stored” and “Background sync: Not running” were unsupported observations. Replaced with current model states and explicit unobserved credential/permission report codes. | Fixed in package 29; engineering reviews schema on new capability |
| D2 / medium | Activity claimed no live actions had run despite only recording sample policy changes. Relabeled as sample history, explicitly excluding local reads, provider activity and durable journals. | Fixed; engineering wires a real audit viewer only with live composition |
| D3 / medium | Generic sync error advised retry without qualifying an uncertain write. Now directs review/verification first; diagnostics provides navigation only. Existing executor blocks incomplete operations and recovery performs confirmation reads rather than replay. | Fixed copy; signed/provider uncertainty remains a release gate |
| D4 / medium | Newly implemented report sheet initially opened blank in native testing because optional state was separate from presentation state. Bound sheet presentation to the immutable report item. | Fixed before acceptance; native first-open check repeated |
| G1 / high release blocker | Signed IPC/native pairing, current OS enforcement and real provider mutation conflict/atomicity evidence remain missing. Internal types and synthetic tests are not runtime authentication. | Engineering + maintainer; isolated signed acceptance before activation |
| G2 / high release blocker | Notes G1–G6 and remote R1–R6 are deferred, not secured working integrations. | Existing ADR-0031/0032 owners and isolated setup triggers |
| G3 / medium release blocker | Live provider audit viewer, full VoiceOver/keyboard/contrast/large-text matrix and sustained provider-load profiling are not verified here. | Engineering; isolated supported-service integration before release claims |
| G4 / high release blocker | User-selected file entitlement compiles, but unsigned testing cannot prove signed sandbox denial outside the chosen destination. | Engineering + maintainer; signed export/cancel/denial acceptance before distribution |

## Boundary evidence

- `CalendarAccessStore`, `CalendarReadStore`, `RemindersStore`, `ContactsStore` keep independent
  opt-in, current authorization checks and generation invalidation. Report capture reads flags only;
  tests use a recording synthetic provider and sensitive query/configuration markers.
- `ConnectionController` loads saved candidates without sessions; pairing consumes the review,
  verifies the channel and rechecks epoch/revision after suspension. Revoke/shutdown close gates;
  persistence failure fails closed. Its 256-entry metadata audit is separate from the 20-entry UI
  sample history. Neither enters the support report.
- Calendar/Reminder/Contact approval engines consume confirmation before suspension, recheck
  session/current observation before dispatch and close further admission after unknown outcomes.
  Synthetic tests cover replay, altered proposal, revoke, stale results and uncertainty.
- `SynchronizationExecutor` blocks incomplete journal operations, records unknown intent before
  send and performs read-only confirmation in recovery. No new UI path calls recovery or replay.
- File settings/storage use private bounded records; default native composition does not open them
  for diagnostics. App startup does not enable providers or Google. The stdio executable retains
  synthetic-only composition; no remote listener/authentication is added.
- Workflow still pins checkout and toolchain, uses read-only tokens and no release credentials.
  No dependencies or domain/provider/transport policy changes are introduced.

These are scoped code/test observations, not an exhaustive penetration test or proof of live service
security. Full supported-service end-to-end acceptance remains owned by engineering, triggered by
maintainer-authorized isolated accounts and signed builds; it is not silently marked complete.

## Validation strategy and evidence

Run the repository's three staged and final-head gates (environment, validate, secret scan), inspect
all changed text/source, verify protected files, test current native disabled-state UI and save a
content-free report only to a task-owned temporary file. Profile that default state with bounded
process CPU/RSS samples. No test enables Apple services, live Google, Notes or remote access.
See [package acceptance](../implementation/prs/pr-29.md#implementation-and-acceptance) for measured
results and exact-head handoff. No benchmark, scanner or synthetic test establishes live acceptance.

Scoped resource sample: six `ps` observations at five-second intervals over 25 seconds with the
report preview idle and all services off recorded 0.0% CPU and 130,784 KiB RSS throughout. This is
one unsigned work-Mac snapshot, not a load/leak/energy benchmark or a provider-performance claim.
App quit and process exit were verified.
