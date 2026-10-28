# Validation and evidence

## Local commands

Full Xcode 27.1 (27A9275), Swift 6.4, and SDK 27.0 are required by
`Config/Toolchain.env` on both Macs and CI. `check_environment.sh` verifies them
and selects matching Xcode per process; `DEVELOPER_DIR` selects a custom location.
See [development setup](setup.md); no global selection change is necessary. Python 3 is used only for repository checks, never as an app daemon.
`curl`, `shasum`, Git, and internet access are needed for the pinned secret scanner.

Stage intended changes before running checks so privacy/secret checks cover new
files. Review `git diff --cached` and make sure the index matches intended sources.

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

`validate.sh` first runs the strict toolchain preflight, then Swift formatting lint, warnings-as-errors package build/test,
domain dependency/import and positive/negative compile checks,
unsigned Xcode Debug build/analysis and Release build, privacy-checker regression
tests, indexed-file privacy checks, and whitespace checks. Xcode's analyze action
is supplemental; this all-Swift skeleton does not have a dedicated semantic
security analyzer. Swift compilation/concurrency checking is the primary static
analysis today. No CodeQL coverage is claimed.

`scan_secrets.sh` downloads Gitleaks 8.30.1, verifies an embedded SHA-256 archive
hash, and scans all fetched Git history plus the exact index. Output is redacted.
It does not scan ignored local files or prove absence of private information.
Release archives/hashes come from [upstream](https://github.com/gitleaks/gitleaks/releases/tag/v8.30.1).
Do not add broad scanner exclusions to suppress a real leak. Revoke leaked secrets
and handle history separately; deleting the current file is insufficient.

Swift smoke coverage tests package linkage and bundled synthetic resource loading.
Python regression tests cover prohibited exports/databases/credentials, misleading
extensions, binary files, symlinks, fixture declarations, and valid source files.
Preflight regression tests use synthetic executables to verify custom paths with
spaces, mismatch rejection for Xcode/build/Swift/SDK, missing-Xcode diagnostics,
and rejection of compatibility overrides in CI. They do not prove a real Xcode
installation. They also check that Xcode is selected before invoking the bundled
Python launcher, so no global developer selection is required for that probe.
There are currently 211 Swift tests (29 executor + 24 planner + 19 persistence + 50 Google authentication/destination + 34 application + 15 Calendar adapter + 21 policy + 18 domain + 1 foundation) and 13 Python tests. The app scheme has no test targets;
use `validate.sh` to execute the package tests rather than relying on its Test action.
No live EventKit/TCC, OAuth, sync, MCP, maintained UI automation, or real-account coverage
is claimed. Work package 05 has scoped one-off native UI inspection in
[ADR-0010](../architecture/decisions/0010-native-application-foundation.md), separate
from automated test coverage. Use a generic macOS destination for universal builds;
a native destination without matching ONLY_ACTIVE_ARCH can mismatch app/package slices.

If baseline Xcode is unavailable locally, `bash Scripts/validate.sh
--allow-toolchain-mismatch` (on one shell line) runs supplemental checks and prints
that limitation. CI rejects this override. Report strict baseline validation as
blocked locally until the matching Xcode is installed; never call compatibility
results baseline parity. This prevents one Mac's toolchain drifting silently.

## Hosted CI

`.github/workflows/ci.yml` is authoritative:

| Check | Environment | Command |
| --- | --- | --- |
| Build and test | xcode-27, Xcode 27.1 | `bash Scripts/validate.sh` |
| Secret scan | ubuntu-24.04, Gitleaks 8.30.1 | `bash Scripts/scan_secrets.sh` |

The build job uses a fresh checkout in `MacHandle clean checkout` (a path with
spaces), without transferred caches or a hard-coded developer directory. It runs
the same strict version check and commands as both Macs.

Both jobs run for every PR and push to main, without path filters or privileged
`pull_request_target`. There is no publishing workflow. Dependabot tracks GitHub
Actions; runtime dependency vulnerability scanning becomes necessary when runtime
dependencies are added. Currently the package has none.

After the first observed successful jobs, preserve all existing main rules while
adding their actual names as required status checks. Record repository settings
and hosted evidence in [progress](../implementation/progress.md). Local success is separate from hosted
success, launch testing, sandbox validation, minimum-OS support, and notarization.

Build output stays in ignored `.build/`. Keep logs outside Git and do not attach
private diagnostic output to a public PR. See progress for this PR's evidence.

## PR-02 feasibility evidence boundaries

PR-02 retains documentation only. Its [brief](../implementation/prs/pr-02.md#evidence-and-experiments)
includes a complete temporary Bash/Swift recipe and exact API symbols/flags; the
recipe is executed as a compile-only check and never runs provider
code. An expected negative typecheck proves native macOS lacks Contacts `.limited`
in the inspected SDK. No new maintained tests are needed without retained prototype
code; standard checks still run on the staged documentation and final commit.

The [ADRs](../architecture/decisions/README.md) assign future synthetic runtime gates:
TCC grant/deny/revoke and source completeness; signed helper peer rejection; Google
scoped CRUD/privacy/refresh/revocation; connection pairing/replay; lifecycle/energy;
and signed Keychain upgrades/minimum-OS distribution. Those checks require their
respective authorized implementation and isolated fixtures, not personal accounts.
Report each category separately from compilation and the existing foundation tests.

## PR-03 domain validation

`CoreDomainTests` uses the public module API and synthetic values only. It exercises
namespaced identity, finite/half-open intervals, Gregorian validation and all-day
representation, moved occurrence anchors, unknown/nonrecurring distinction, scoped
reads, incomplete/empty/failure/freshness distinctions, availability bounds, reminder
wall-clock due dates, Contact identity/fields, exact patches and proposal bindings.
No implicit clock, TCC request, network, live account or Keychain access is used.

After SwiftPM build/test, `check_domain_boundaries.sh` verifies CoreDomain has no
target dependencies or non-Foundation imports. A positive compiler control verifies
both public protocols are usable; three invalid programs must fail with the expected
diagnostic categories: calling a writer through CalendarReading, passing ConnectionID
as EventID, and deleting a unified ContactReference as an underlying record. It uses
the selected toolchain/product path, supports SwiftPM's Swift Build and native layouts,
and removes temporary fixtures on exit. These checks run in the existing hosted
Build and test job through validate.sh; no extra secrets or permissions.

The checks establish static/model behavior, not provider fidelity, complete upstream
state, policy enforcement, cryptographic approvals, runtime sandboxing or real
recurrence/DST expansion. All-day query membership and provider normalization remain
later adapter checks. See [ADR-0008](../architecture/decisions/0008-core-domain-contracts.md).


## Work package 04 policy validation

PermissionEngineTests exercises public APIs with synthetic identities and data only:
default deny, service-specific OS observations, namespace/connection isolation,
operation escalation, exact changed-field grants including clearing, hidden Contact
search fields, source-sync write denial, resource/field projections, unified-record
rejection, receipt binding, policy tightening, revocation and remove/recreate.
No @testable access, real authentication, OS permission prompt or provider executes.

The boundary script now enforces PermissionEngine -> CoreDomain only and imports
limited to CoreDomain/Foundation. Alongside three domain probes, four new compile-fail
checks reject session administration, accessing its internal authority, constructing a
PolicyPermit, and retrieving source coverage/IDs from PermittedAvailability. The
positive control compiles valid session evaluation. All seven expected rejections
run through validate.sh in local and hosted checks; diagnostics are matched and
all temporary fixtures are removed. Existing tests/checks/CI permissions remain intact.

Revalidation/projection tests prove behavior in actor order, including revocation
before a pending response is filtered. They do not prove atomicity with a future
external provider or recall of already returned data. See
[ADR-0009](../architecture/decisions/0009-permission-policy-engine.md) for operation
sequencing obligations and the distinction between policy receipts and local approval.

## Calendar discovery verification

Work package 06 adds synthetic opt-in/selection/race tests and pure EventKit status
mapping/notification tests. These do not instantiate a real event store or prompt.
The default signed development app was inspected only in its off state. A disposable
copy of the app with an injected synthetic provider exercised native selection and
denied/incomplete/unavailable/empty states, without Calendar entitlement or real data.
The harness is outside Git and does not add a production bypass. Effective built
Info.plist/entitlements were separately inspected. [ADR-0011](../architecture/decisions/0011-calendar-authorization-discovery.md)
records live TCC/sandbox and device gates; they are not satisfied by local CI.

## Calendar read verification

Work package 07 adds 19 synthetic tests for exact calendar selection, half-open bounds,
400-day limits, original recurrence anchors, all-day/DST/skipped-date resolution,
partial/unknown coverage, availability projection, hidden detail fields and reads
interrupted by selection, mode, cancellation or permission changes. A final permission
check is exercised after response filtering. No test creates a real EventKit store.
An eighth compiler rejection proves CalendarReading cannot request OS access.

A disposable native harness verified availability/title/detail modes, result clearing,
partial-coverage messaging and scroll layout using synthetic strings only. This is
one-off UI inspection, not maintained UI automation or live provider proof. The real
adapter compiles in the universal Debug/Release builds. Live recurrence expansion,
TCC grant/deny/revoke, sandbox reads and source freshness require a separately authorized
isolated Calendar account/device; maintainer/provider work owns this gate before
milestone A acceptance. See [ADR-0012](../architecture/decisions/0012-calendar-reads-availability.md).

## Google authentication verification

Work package 08 adds 22 tests using synthetic protocol/credential values and injected
HTTP/browser/storage/clock dependencies. They cover RFC PKCE, state/redirect/Host,
duplicate/malformed callbacks, scope rejection, token rotation/invalid grants,
locked/unavailable stores, coalescing, cancellation, stale-result fences, local delete,
remote revocation failures and the unconfigured UI. Tests inspect Keychain query
attributes but never call SecItem APIs or store real secrets.

Two tests use a real unsandboxed Network listener on an OS-assigned 127.0.0.1 port,
with synthetic callbacks, refusal of wrong state, timeout and cancellation. They run
in the standard suite without accounts or external network calls. A ninth compiler
probe rejects accessing private credentials through GoogleAuthentication; the target
must have no Calendar/policy/MCP dependency. The native development build's disabled
Google controls/setup messaging were inspected separately. No signed Keychain or live
Google/browser-consent/sandbox acceptance is claimed. See
[ADR-0013](../architecture/decisions/0013-google-oauth-keychain.md) and
[activation setup](google-auth-setup.md).

## Work package 09 destination evidence

Nineteen synthetic tests add owned CRUD/If-Match, privacy payload removal, unmapped/
foreign targets, uncertain inserts/collisions, quota/Retry-After, complete pagination
and bounded malformed/oversized responses. Real authentication actors with fake stores,
token exchange and HTTP verify refresh/disconnect/401/cancellation fences. No Google
API, real token, Keychain item or user content is used. Eleven total compile-fail
probes include rejection of external destination construction and lease acquisition.
Live privacy, durable recovery, signed networking and provider acceptance stay open.

## Work package 10 storage evidence

Fifteen storage tests use real SDK SQLite with disposable synthetic files in private
temporary directories. They exercise migration/rollback, restart with unknown outcomes,
checkpoint/version conflicts, tombstones, identity isolation, malformed/newer schemas,
private permissions, writer exclusion and symlink/replacement rejection. An abandoned
uncommitted connection verifies rollback on reopen; this is not power-loss/disk-full
proof. No app database, provider or personal data is accessed. A twelfth compiler probe
rejects raw SQL access. The app links SyncPersistence for universal build/analyze checks
without opening it. Signed/minimum-OS, online backup and cross-Mac recovery stay open.

## Work package 11 planning evidence

Eighteen pure public-API tests cover projection/clearing, deterministic ordering and
fingerprint vectors, create/update convergence, conflict and uncertainty handling,
bounded-horizon deletion, tombstones and safety bounds. A thirteenth compiler probe
rejects planner proposals passed to an Apple writer; dependency/import guards keep
planning separate from providers and SQLite. No live end-to-end or executor coverage
is implied; see [ADR-0016](../architecture/decisions/0016-pure-reconciliation-planner.md).

## Work package 12 execution evidence

Fifteen integration tests combine real temporary SQLite, planner/executor/Google client
and synthetic HTTP. They cover durable ordering, convergence, conditional/privacy updates,
delete confirmation, lost responses, store reopen, failed result persistence, missing
recovery targets, revocation/retry, partial success, cancellation/concurrency and precision
rejection. Two compiler probes prevent external executor/bridge activation (fifteen total).
No actual network, Apple provider, account or Keychain is involved. The default authority
denies work; tests do not prove a live authorization adapter. See
[ADR-0017](../architecture/decisions/0017-synchronization-executor.md).


## Work package 13 recurrence and time validation

Seventeen added synthetic tests exercise bounded occurrence normalization, changed/
cancelled instances, mixed/unknown anchor rejection, calendar scope changes, DST repeated
times, all-day travel and multi-day exclusive ends, leap-year/local-day horizons and
lossless-or-rejected Google timestamps. Provider-normalized records pass through the
real planner, temporary SQLite store, internal executor and synthetic Google transport.
Assertions bind stable IDs, conditional operations, zero repeat writes and no horizon
deletion. The executor test target may import the provider fixture; production dependencies
remain unchanged. Legacy content-v1 baselines conflict rather than silently migrate to v2.
See [ADR-0018](../architecture/decisions/0018-recurrence-time-correctness.md) for exact
provider assumptions and signed/live acceptance still required before activation.

## Work package 14 recovery coverage

Twenty-one added Swift tests exercise complete destructive-plan approval, incomplete/
revoked source denial, original prepared-intent recovery, new-client/store restart,
unknown creation/write replies, retained metadata import, full-inventory recovery,
legacy rebaseline/source migration, atomic rollback and writer handoff races. Transfer
fails while busy or when writes/journal remain unresolved; unknown transfer leaves the
old session in standby. The legacy v1 fingerprint also has an independent known vector.
The added external recovery probe raises compiler rejections to sixteen.

These tests use real local SQLite and the actual planner/client/executor with synthetic
HTTP. They do not prove real account identity, signed Keychain/storage, actual calendar
ETag behavior, source migration continuity, power loss or two physical Macs. See
[ADR-0019](../architecture/decisions/0019-deletion-safety-recovery.md) and the
[recovery procedure](sync-recovery.md) for required trusted adapters and acceptance gates.
