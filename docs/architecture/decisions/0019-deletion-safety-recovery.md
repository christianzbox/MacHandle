# ADR-0019: Deletion safety, recovery and writer handoff

Date: 2026-10-28. Status: implemented for work package 14 review; live activation denied.
See [brief](../../implementation/prs/pr-14.md), [recovery procedure](../../development/sync-recovery.md),
[ADR-0015](0015-sqlite-persistence.md), [ADR-0017](0017-synchronization-executor.md)
and [ADR-0018](0018-recurrence-time-correctness.md).

## Context and decisions

A failed source read, missing account, corrupt database or incomplete destination inventory
cannot prove deletion. Existing planner uncertainty guards remain mandatory. The executor
now also requires trusted approval of the exact complete plan whenever any deletion is
present. This approval defaults to deny and is checked again at reads, mutation attempts
and local commits. Individual item approval alone cannot authorize a destructive batch.
Choosing confirmation for every batch avoids a numerical threshold that small batches
could evade. Confirmation UI and actual source freshness remain package 16 obligations.

Recovery is internal, explicitly authorized and read-first. A newly authenticated Google
client can restore a candidate destination only after a trusted callback establishes the
actual account/client and durable creation lineage, then verifies remote ownership under
the same authentication lease. Remote descriptions and caller-supplied IDs are evidence,
not authority. Restoring without an assigned writer identity yields standby capability.
Legacy UUID-only descriptions can be verified read-only; they cannot silently gain a writer.

A retained immutable metadata snapshot may be imported into an empty replacement store
bound to the same Google client/account. It preserves remote IDs, creation history, ETags
and tombstones; it never overwrites the damaged original. Prepared operations in a backup
become unknown because the backup could predate dispatch. Checkpoints reset and imported
metadata does not authorize writes. No backup serializer, file import UI or content export
is implemented. With no retained metadata or creation lineage, recovery stops for intervention.
This is safer than reconstructing identity by titles or current occurrence times.

Verified metadata recovery requires complete one-to-one old/new source identity bindings,
creation lineage, an exact active remote ID inventory before and after verification, and
per-event owner, privacy, reminders, ETag and last-exported content checks. Tombstones must
remain absent. Legacy content-v1 is accepted only if independently recomputed from retained
last-exported content including its original timezone, and the remote baseline matches.
Only then is content-v2 recorded. One SQLite transaction compares the entire expected
snapshot and changes source keys/fingerprints, preserves all remote identities/history,
and invalidates run completion. Source account migration is a reviewed source rebinding,
not movement to another Google account. Partial inventories/backups, stale reviews,
remote edits and absent evidence fail closed. No event is recreated during recovery.

A prepared intent in the original store can resume once with its original operation/event
IDs and a newly computed exact plan and trusted approval. Unknown operations are verified
by reads, never blindly replayed. A lost calendar-create response requires a separately
provided candidate calendar ID, the original durable creation intent and verified empty
owned inventory. It never sends a second calendar POST or broadens discovery scopes.

## Cooperative writer protocol

New destination descriptions contain bounded versioned JSON with creation owner, writer
installation UUID and generation UUID. New trusted composition must supply its durable
installation identity. Every event mutation attempt re-reads this state under the current
authentication lease. An exact recipient can receive ownership only after the current
writer drains writes and resolves its journal. The client rejects handoff while busy or
while a remote write remains unverified; the coordinator checks the unchanged local
snapshot and trusted recipient approval before each HTTP attempt.

The old session relinquishes its local writer capability before a conditional description
PATCH, using the observed calendar ETag. A confirming GET must match the new generation.
An unknown response leaves the old session in standby; there is no blind transfer replay,
expiry or forced takeover. The recipient must separately restore and verify its assigned
identity. Restarted old writers fail the remote generation check.

Google documents [ETag/If-Match conditional modifications](https://developers.google.com/workspace/calendar/api/guides/version-resources)
and [calendar PATCH with calendar.app.created scope](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/patch).
PATCH preserves unmodeled calendar metadata at the cost of its documented extra quota
units. These documents support the protocol design, not proof of actual account behavior.
The scope, transport authority, privacy and conditional event-write checks are unchanged.

This is an orderly, cooperative single-writer protocol, not a cross-resource transaction
or an adversarial distributed lock: the calendar ETag cannot atomically fence event writes.
Trusted composition must keep one canonical store/client per installation, stop the old
writer before transfer, reject cloned installation identities and enforce compatible clients.
A local file lock protects only one canonical local store. Manual Google edits, cloned
credentials/stores and external writers fall outside the demonstrated guarantee.
A timed lease could permit a suspended old Mac to resume after expiry; a cloud coordinator
adds a service/authority dependency. Neither is introduced. An unavailable original writer
requires controlled intervention rather than an automatic takeover that risks overlap.

## Evidence, consequences and remaining gates

Twenty-one added Swift tests exercise destructive approval, source uncertainty, exact-ID
prepared recovery, new-client restoration, lost creation/write/transfer replies, incomplete
inventory, metadata migration, rollback and handoff races. The legacy digest also has an
independent known vector. The real planner, SQLite store and Google client run against
synthetic transport; the external recovery compile probe must fail. No new module,
dependency, schema version, OAuth scope, entitlement or live app entry point is introduced.

The app remains inactive. Engineering owns trusted account/source continuity, canonical
store/installation composition, confirmation UI, durable backup acquisition and signed
Google/privacy acceptance before package 16 activation. Legacy destination writer bootstrap
is deferred until a controlled, explicitly reviewed migration is needed before activation;
no prior live sync was enabled. Total metadata loss, uncertain absence, missing old writer
and unknown transfer outcomes remain manual intervention, never implied permission to reset
or recreate. Live conditional requests, actual two-Mac transfer, power loss, home Mac and
minimum OS behavior require isolated signed acceptance before release. Package 15 owns
sleep/wake/network scheduling and retry orchestration; this package only supplies safe
recovery primitives. See [progress](../../implementation/progress.md) for exact checks.

## Work package 15 follow-up — 2026-10-28

[ADR-0020](0020-background-synchronization.md) implements the internal monotonic coordinator,
serialized drain/cancellation, bounded preparation retries and native lifecycle adapters.
Settings now has explicit launch-at-login control; it never enables synchronization.
Pause/drain precedes writer transfer, and durable journal recovery remains mandatory.
Synthetic lifecycle and idle harness evidence are separate from signed login, locked
Keychain, physical sleep/network and two-Mac acceptance. Trusted live composition remains
package 16, not an automatic consequence of enabling login.

## Work package 16 follow-up

[ADR-0021](0021-google-sync-onboarding.md) adds native local onboarding, retained reviews,
serialized composition and schema-v3 candidate preferences. Existing authority/recovery
checks remain independent. Signed/live composition, private-sharing proof and actual
account acceptance remain an owned activation follow-up; they are not satisfied by the
new UI or transferred to MCP. The default app remains unconfigured.
