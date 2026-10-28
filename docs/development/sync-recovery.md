# Synchronization recovery procedure

This is an engineering procedure for the internal work package 14 contracts. It is not
an available app workflow. Live sync remains disabled. Read
[ADR-0019](../architecture/decisions/0019-deletion-safety-recovery.md),
[setup](setup.md) and [account setup](google-auth-setup.md) before future signed acceptance.
No new account or key is needed to run the synthetic tests.

1. Pause scheduling and preserve the damaged original store. Do not delete it, copy an
   active SQLite database, replay unknown writes or create another destination. Retain
   metadata privately; never put snapshots, account identifiers or source content in Git.
2. Reauthenticate the actual Google account/client. Obtain candidate destination identity
   and durable creation lineage independently. Restore as standby by default; a matching
   remote title or description does not grant authority. If evidence is missing, stop.
3. Recover unknown results by verifying the original IDs. An absent unknown insert is
   not automatically safe to retry. Only a never-dispatched prepared intent in the
   original store may resume after fresh complete observations and exact approval.
4. For local loss, acquire a consistent retained metadata snapshot through trusted code
   and import into an empty replacement store. No snapshot serializer/import UI exists
   yet. Same Google account/client binding is required; a new installation ID requires
   explicit device transfer. Imported prepared operations become unknown. Do not reuse
   an old completed checkpoint as evidence of current reconciliation.
5. Review every original/replacement source identity and last-exported baseline. Verify
   complete owned remote inventory, each event's creation lineage, content, privacy,
   ETag and tombstone absence. Approve the exact immutable recovery review. Apply local
   metadata changes atomically only while the snapshot remains unchanged. Incomplete
   backups or changed remote content require intervention, never replacement inserts.
6. To transfer, keep the recipient in standby, stop the old writer and resolve all
   pending operations. Approve the exact recipient installation. The original client
   performs the conditional writer update and readback after relinquishing its own
   capability. The recipient restores only its assigned generation. A failed/unknown
   transfer keeps the old session in standby; inspect with authenticated reads rather
   than retrying blindly. An unavailable old writer has no automatic takeover path.
7. Before resuming, obtain fresh complete source/destination observations, verify account,
   selection, field policy and writer identity, and obtain a new preview. Approve the
   exact entire destructive plan as well as each deletion. Recovery alone never marks
   synchronization successful.

Engineering must implement the trusted UI/account/backup adapters in package 16 and
prove actual signed Google behavior, identity continuity and two-device exclusion before
activation. One canonical store/client per installation and compatible client versions
are required. Duplicated installation identities, manual remote control edits and old
clients are outside this cooperative protocol. Legacy UUID-only destinations remain
read-only until a controlled migration is designed and verified. Keep source Calendar
access read-only and preserve original Apple resources throughout recovery.
