# ADR-0015 — Versioned local sync persistence

Date: 2026-10-27. Status: work package 10 merged in GitHub PR #11 at
`4a5ad09a22be45b681c46675d756500603a58d8c`; not activated in the application. Requirements: specification PR-10 and §§6, 7, 13, 20 and 22. Prerequisite
GitHub PR #10 merged at `928732effe0985ed34a386cba4367ffd69bdc43c` on 2026-10-27
19:29:13 UTC. No database, personal content or credentials are committed.

## Decision and alternatives

Add a cohesive SyncPersistence Swift target using the macOS SDK's SQLite3 library.
It depends on Foundation, Darwin and SQLite3 only. Domain, policy and Google modules
remain independent. Public contracts contain immutable values and sanitized errors;
the SQLite connection and SQL execution remain private. The app links the product for
universal compile validation but never constructs a store. Startup behavior is unchanged.

A raw SQLite adapter keeps transactions and durability choices explicit without adding
a runtime package dependency. An ORM would reduce boilerplate but introduce another
migration/concurrency layer; JSON/preferences lack the required relational atomicity.
A separate persistence target prevents storage details entering CoreDomain. The small
unchecked-Sendable connection is owned by one actor, with no suspension inside a
transaction and explicit statement finalization/close. No general SQL API is exported.

Official SQLite references checked 2026-10-27:

- [PRAGMAs](https://www.sqlite.org/pragma.html): schema/application versions, integrity,
  foreign-key checks, journal and synchronization settings. Critical settings are read
  back because SQLite can silently ignore unsupported PRAGMAs.
- [Atomic commit](https://www.sqlite.org/atomiccommit.html): rollback transactions and
  filesystem/hardware assumptions. Tests here are not power-loss or hardware proof.
- [Backup API](https://www.sqlite.org/backup.html): a future online backup needs a
  consistent SQLite snapshot rather than copying an active database blindly.

## Schema and migration contract

The database uses a fixed application ID and user_version. Version 1 introduces store
identity, resource mappings and event mappings. Version 2 adds pending operations,
paused/recovery-required sync state and a compare-and-swap checkpoint. These are the
first internal schema versions, not a claim that v1 was shipped to users.

Each migration runs in BEGIN IMMEDIATE/COMMIT; failure rolls back schema, data and
version together. Known old versions migrate only after application ID, exact schema
manifest and expected identity match. Unknown/newer versions and unexpected objects
fail closed. Integrity and foreign-key checks detect structural violations; row decoding
checks UUIDs, digests, opaque IDs, versions and state. No silent repair, overwrite,
quarantine copy, reset or deletion occurs. Files remain available for explicit recovery.

Tables use STRICT types, foreign keys, unique source/destination mappings, a composite
event/resource relationship, operation-shape/state checks and at most one unfinished
operation per event. Values are bound parameters; SQL is implementation-owned. Reads
and retained records are bounded at 10,000 rows, file size at 128 MiB, SQLite values at
1 MiB. Reaching a limit stops work; retention/compaction is a later recovery decision.

## Durable operation identity and restore boundary

Each store is bound to an expected store UUID, installation UUID, public OAuth client
ID and opaque account digest. The trusted caller must obtain the actual account binding;
this module cannot authenticate it and does not invent an OAuth identity lookup. Matching
stored text is not Google authority. Resource/occurrence keys and fingerprints are
64-character hex digests; they are not anonymous, encrypted or necessarily keyed.

prepareDestination persists a resource and stable operation/ownership marker together.
prepareInsert persists an event mapping, stable UUID-hex remote ID, desired fingerprint
and operation together. Updates/deletes require a recorded event version and prior
completed creation history. Unique constraints prevent silent duplicate mappings;
tombstones retain identity and cannot be resurrected by another insert.

beginAttempt commits state=unknown and recoveryRequired **before** returning to a
future executor. Only prepared operations can enter that state. A lost response or
restart retains the same operation/event identity; there is no automatic retry or new
ID. Result recording atomically updates mapping/fingerprint/ETag or tombstone and
completes the operation. Failed result commits leave the prior unknown state intact.
An executor must verify remote identity/content/outcome before calling these recording
methods; they record observations and do not confer provider capabilities.

Checkpoints use an expected revision and cannot advance while any operation remains
prepared/unknown. They record local bookkeeping, not source completeness, authorization
to delete, remote success across a distributed transaction or sync acceptance. Every
snapshot explicitly requires remote verification; it never declares itself ready to
execute. Migrated legacy mappings without creation history remain readable candidates
but cannot prepare writes. Missing rows/versions, corrupt state or binding mismatches
never become deletion instructions or permission to recreate a destination.

## Filesystem, durability and privacy

Trusted activation should choose an app-owned local Application Support subdirectory
separated by development/production identity and store UUID, inside the sandbox container
when applicable. This package accepts an explicit directory for composition/tests; no
location is opened automatically. Cloud/network folders are not the supported design.

Creation is explicit and exclusive. Resume never creates a missing database. A surviving
writer.lock also prevents createNew from erasing evidence after database loss; it is not
an authorization token. Directories require owner-only access (0700), files 0600, matching
owner, regular-file type and single link. Symlinks are rejected; libc realpath resolves
macOS ancestor paths before SQLite's NOFOLLOW open. Database/lock identity and sidecars
are rechecked while in use. No existing unsafe permissions are silently relaxed/fixed.

A separate advisory writer.lock is held for the connection lifetime, avoiding conflict
with SQLite's own locks on the database. It excludes cooperating local store instances,
not other Macs or a hostile same-user process. Filesystem checks do not eliminate every
same-user path race. This is not an anti-tamper or cross-device ownership guarantee.

Use DELETE rollback journaling, foreign_keys=ON, synchronous=FULL, fullfsync=ON,
trusted_schema=OFF and secure_delete=ON. A bounded busy timeout returns an error rather
than waiting indefinitely. WAL was considered; one serialized writer does not need its
concurrency benefit, and rollback journaling simplifies sidecar/backup recovery. A live
SQLite error that makes storage unreliable poisons the connection until close/reopen.

Persist only identity/mapping/version/fingerprint/operation/checkpoint metadata. There
are no token, password, event title/detail, attendee, payload or provider-error columns.
Metadata still reveals associations and is plaintext under OS file permissions; this
is not SQLCipher encryption or a guarantee of secure erasure. Future live deployment
must review OS disk protection, backup retention and signed sandbox behavior. Tokens
remain solely in the existing private Keychain implementation.

No backup/export feature or automatic OS-backup exclusion is added. OS backups may
contain this private metadata. Any restored/copied database remains a recovery candidate,
not writer authority. Never copy an active database as a handoff or commit it to Git;
future backup/restore work must use a consistent snapshot and revalidate identity.

## Evidence and remaining gates

Fifteen tests create disposable synthetic files and exercise resume/isolation, stable
unknown operations, versioned updates/tombstones, checkpoint conflicts, failed commits,
frozen-v1 migration/rollback, abandoned transactions, foreign keys, corruption, newer
schemas, private permissions, local writer exclusion and symlink/replacement rejection.
One new compile-fail probe prevents accessing raw SQL. Final strict local/hosted evidence
is recorded in the review PR and [progress](../../implementation/progress.md).

Deferred integration owner: package 12 executor and package 14 recovery. Revisit after
those packages are authorized: bridge durable records into the internal Google client,
verify real account binding and remote ownership, handle ambiguous outcomes and enforce
one destination writer across Macs. No live client imports this module yet. Package 11
owns pure planning, not dispatch. Privacy/OAuth/signed/minimum-OS/home-Mac/release gates
remain open. Power-loss/disk-full injection, online backup and signed storage acceptance
remain recovery/release gates; synthetic rollback tests do not establish them.

## Work package 11 planning follow-up

[ADR-0016](0016-pure-reconciliation-planner.md) adds pure comparison contracts. It does
not consume SQLite records directly or convert them into provider authority. Packages
12/14 still own trusted adapters and recovery; checkpoint values never imply completeness.

## Work package 12 executor follow-up

[ADR-0017](0017-synchronization-executor.md) uses existing prepare/unknown/result/checkpoint
transactions with synthetic provider integration. No schema change is needed. Store reopen
recovery retains operation IDs; rebuilding ownership after provider-process loss and other
recovery gates remain package 14. The app still never opens a store.
