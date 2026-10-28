# ADR-0020: Background synchronization and login lifecycle

Date: 2026-10-28. Status: implemented for work package 15 review; live sync inactive.
Requirements: specification [§7](../../product/master-spec.md#7-google-calendar-synchronization),
[§12.5](../../product/master-spec.md#125-background-behavior),
[PR-15](../../product/master-spec.md#pr-15--background-synchronization).
Read [ADR-0007](0007-lifecycle-identity-and-distribution.md),
[ADR-0017](0017-synchronization-executor.md), [ADR-0019](0019-deletion-safety-recovery.md)
and [acceptance](../../implementation/prs/pr-15.md#implementation-and-acceptance).

## Decision and trust boundaries

Keep the initial coordinator in the existing SyncExecution module. It receives an explicit
job, monotonic clock, change stream and scheduling conditions. It defaults paused, offline
and standby. There is no public activation factory. The default app does not construct a
coordinator or subscribe to network/workspace signals: trusted account/source/writer
composition remains package 16. No module/dependency, entitlement, database migration or
provider write authority is added. Google scheduling does not depend on MCP.

After trusted setup and explicit resume, perform a fresh reconciliation, then schedule
one run five minutes after completion (configured interval clamped to 60–3600 seconds).
Use one cancellable ContinuousClock sleep with tolerance, not polling. No missed-period
catch-up queue is accumulated. Source changes use a two-second trailing debounce capped
at ten seconds; the existing EventKit provider supplies bounded content-free signals.
Signals invalidate the current generation and cancel stale work; they never prove source
completeness, upstream deletion, permission or approval. The ten-second debounce cap bounds
quiet time only; it cannot guarantee completion while the source continually changes.

ScheduledSynchronizationJob checks durable pending intents before fresh observation and
passes a newly computed plan through the existing executor. Its wrapped authority checks
the scheduler generation before/after trusted observations and every operation/approval
check. Per-event remote writer, source freshness, privacy, ETags and exact destructive
batch confirmation remain mandatory. No cached preview becomes an automatic approval.
Only a known transient preparation failure before dispatch may request a retry: honor the
server floor, bounded exponential minimum (5/10/20 seconds), up to one second of jitter,
maximum three retries and maximum accepted delay one hour. Invalid/long hints require
attention rather than an early retry. Source signals, network flapping and concurrent
invalidation do not erase a returned server backoff. Explicit resume may reset the retry
budget but retains an existing server deadline. Any non-completed executor outcome requires
attention; pending/unknown writes must go through the reviewed recovery workflow.

Pause, sleep, offline or standby invalidate and cancel active work. Cancellation is not
rollback: an accepted remote mutation may finish and remain unknown. The worker slot is
retained until the old job returns, even if it ignores cancellation. Await pauseAndDrain
before transferring the writer; overlapping drains block resume until all have completed.
The existing recovery coordinator independently requires a resolved durable journal.
Shutdown also cancels the source subscription and prevents subsequent resume. A hung job
blocks progress safely; no timeout creates a second writer.

## macOS adapters and visible behavior

MacHandleApplication supplies an explicit-lifetime BackgroundEnvironment using
[NSWorkspace sleep/wake notifications](https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification)
and [NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor).
It also observes session activation and power-off. The newest buffered item includes all
awake/session/network flags, so coalescing cannot overwrite a sleep flag with a network
update. Old-generation path callbacks are ignored; stop removes observers and cancels the
monitor. The future trusted host must map awake AND sessionActive to scheduling eligibility,
consume the state stream, and stop both adapter and coordinator on shutdown. These signals
are hints, not network authentication, service availability or lock-state proof. No private
screen-lock notification or permission request is used.

Settings now exposes a separate explicit launch-at-login control through
[SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp).
The service's current status is the source of truth, reread after changes and on foreground.
No preference boolean silently re-registers a user-disabled service. Approval-required,
unavailable, in-progress and failure states are distinguished. Enabling login never enables
sync or requests Calendar/Google access. The adapter calls register/unregister only after
the user's Settings action; no login registration was performed during implementation.
Closing a window keeps the app/menu alive; Quit ends it. No daemon, power assertion,
root access, background process after Quit or operation while asleep/off is promised.

## Alternatives, evidence and limits

A separate login agent/helper could outlive the UI but would add an authority/process owner;
the current requirements do not justify that complexity. A repeating poll or one task per
notification wastes idle work and risks overlap. A monotonic deadline and coalesced signal
avoid wall-clock changes and catch-up storms. Terminal recovery state is preferable to
blind scheduler retries of uncertain remote effects.

Twenty added Swift tests cover scheduler defaults/standby, periodic cadence, debounce and
change streams, cancellation-ignoring jobs, pause/drain, bounded retries and racing backoff,
shutdown, real executor/SQLite/client integration, login state transitions and workspace/
path adapter cleanup. Totals: 231 Swift + 13 Python tests, seventeen compiler rejection
probes. Synthetic native notification delivery is not a real sleep/logout/login experiment.

A disposable optimized Swift harness compiled the actual coordinator and a synthetic no-op
job, then sampled getrusage around ten-second ContinuousClock sleeps. Paused: 10.525s elapsed,
0.000231 CPU seconds, 5,898,240-byte peak process RSS, zero jobs. Enabled and idle after its
initial completion, with a 300s interval: 10.008s elapsed, 0.000122 CPU seconds,
6,029,312-byte peak process RSS, zero additional jobs. This short work-Mac sample includes
harness/runtime memory; it is not whole-app energy, network throughput, battery, long-duration
or minimum-OS evidence. The reproducible method and required live matrix are in
[testing](../../development/testing.md#work-package-15-background-coverage).

Engineering owns package 16's trusted live composition, user pause/status/recovery UI,
restored settings and account/field/source identity checks. Signed login approval/revocation,
real wake/network behavior, locked Keychain, App Nap, idle whole-app energy, minimum OS and
two-Mac transfer remain acceptance gates before activation/release. Lack of signing/account
setup prevents those proofs today; it does not justify silently enabling live sync.
Apple notarization/App Review and Google scope verification are separate processes, neither
proved by tests or account enrollment. See the [setup guide](../../development/google-auth-setup.md).
