# ADR-0021: Reviewed Google sync onboarding and saved preferences

Date: 2026-10-28. Status: implemented for work package 16 review; live activation denied.
Requirements: [PR-16](../../product/master-spec.md#pr-16--google-sync-onboarding-and-preferences),
[§7](../../product/master-spec.md#7-google-calendar-synchronization),
[§12](../../product/master-spec.md#12-native-macos-experience).
See [acceptance](../../implementation/prs/pr-16.md#implementation-and-acceptance),
[ADR-0013](0013-google-oauth-keychain.md), [ADR-0019](0019-deletion-safety-recovery.md)
and [ADR-0020](0020-background-synchronization.md).

## Context and decision

The planner, durable executor and scheduler previously had no shared local onboarding
contract. Put presentation values and the trusted local administrative interface in
CoreDomain, the observable UI model in MacHandleApplication, and the internal workflow
in SyncExecution. Reuse existing modules; no new dependency, scope or entitlement.
Administrative controls must never be forwarded through MCP. Their inputs are choices,
not proof of account identity, OS permission, field authority, privacy or writer ownership.

The native Connections screen now offers source selection, availability-only defaults,
explicit title/location/notes choices, review/confirmation, status, pause, fresh review
before resume, local disconnect and separate project-wide grant revocation confirmation.
Apple permission is still requested only in the existing explicit Calendar opt-in flow.
Google selections are independent of local read selections. Removing fields pauses first;
a subsequent confirmed sync replaces remote fields and clears excluded details. Pausing
alone leaves existing remote data intact. UI model generations discard late responses and
old confirmation-dialog IDs. Preview titles/location/notes come only from planner output;
unchanged/deleted items use generic labels and retained time bounds, not hidden content.

One internal workflow owns a canonical store, its selected source/destination lanes and
one background coordinator. Each lane must use the exact same store actor and identity
binding, a unique selected source and a unique dedicated app-owned destination. This
preserves the existing one-source/one-resource durable schema and per-destination writer
checks. Up to 32 sources may share a privacy configuration. Combining several sources
into one Google calendar would require redesigning existing unique resource mappings;
it is not silently introduced here. The factory returns already verified capabilities;
it does not constitute account, private-sharing, destination-creation or write approval.

## Reviews, execution and lifecycle

A review retains immutable complete plans, source selection, fields, lane capabilities
and a random ID in memory. Its five-minute lifetime is bounded by both wall time and a
monotonic deadline. Confirmation accepts the retained ID, consumes it once, rechecks all
plans before the first mutation, and then delegates to the existing executor. Explicit
whole-set deletion confirmation is required in addition to the independently trusted
base authority's destructive-plan approval. No checkbox bypasses that existing check.

Ongoing consent allows fresh non-destructive plans only; any later deletion requires a
new full reviewed batch. Background input still checks account/source/fields/privacy/
writer authority through the underlying trusted adapter on every privileged step.
The first scheduled interval follows the completed initial run, avoiding an immediate
duplicate run. The batch wrapper conservatively turns any non-completion into attention;
preparation retry optimization remains available in the underlying single-lane job.
Only a completely verified batch updates the session's last-success timestamp.

Pause, changed source/field selection, source changes during a review/manual run, writer
loss, and offline/inactive session during manual work invalidate approval generations.
Owned sign-in, preparation, execution and scheduled work are cancelled and drained before
replacement. A dispatch already accepted remotely can finish; it remains an unknown
journal entry when confirmation cannot complete. No automatic replay follows. Background
sleep/network signals suspend scheduling, while awake AND sessionActive is required.
Shutdown also cancels and drains the source observer. Signals do not grant authority.

Disconnect stops/drains first, asks the injected account adapter to remove local access
(and optionally revoke the grant), clears candidate preferences, and preserves remote
calendars, mappings and operation journals. Failure to confirm credential removal or grant
revocation is shown separately from local stopping. Recovery/standby are visible stopped
states; a fresh preview does not resolve an unknown operation or assume writer ownership.

## Persistence and alternatives

Schema v3 adds one bound preferences row: sorted source fingerprints and a three-bit field
mask. No event content, raw source identifiers, enabled flag, approval receipt, credential
or new account identifier is stored. Migration from v2 is transactional; v1 migrates through
v2. Restoring candidates requires a fresh authorized catalog and exact hashes; renamed/
missing identities are not guessed. Restoration stays paused with no last-success claim.
Retained metadata import carries candidate preferences; verified source rebinding updates
the selected hash in the same transaction. Recovery compare-and-swap includes preferences.

UserDefaults was rejected for trusted account-bound preferences because it is outside the
existing identity/transaction/recovery boundary. Saving an enabled bit or replaying old
reviews was rejected because launch/restoration cannot recreate current approval. A new
all-purpose sync module and a public runtime factory were unnecessary and would expand
activation access. Persisting projected event bodies would violate the metadata-only store.

## Evidence and remaining activation gate

Eighteen added Swift tests cover the local model, real planner/SQLite/executor/synthetic HTTP
workflow, field clearing, stable event IDs, repeat-run idempotency, review changes/expiry/
consumption, deletion approval, inactive sessions, cancellation/drain, late sign-in,
default denial, lost replies, failed disconnect, and preferences/migration rollback.
The eighteenth compiler rejection prevents external workflow activation. Native unsigned
UI inspection verifies the disabled setup screen and opt-in field controls only.

The shipped app injects an unconfigured service: it constructs no auth client, database,
source-event reader, remote destination, scheduler or lifecycle observer for Google. The
new workflow is exercised by isolated synthetic transport, not actual Google accounts.
The exact setup/activation ledger in the package brief is mandatory. Milestone B and the
specification's technically usable end-to-end acceptance are NOT complete. Engineering
and the maintainer must close that follow-up before enabling live sync; package 17 does
not inherit or silently close it. No Apple approval, Google classification/assessment
exemption, signed Keychain proof or release readiness is inferred.
