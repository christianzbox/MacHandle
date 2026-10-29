# Contacts management checks

Read [ADR-0030](../architecture/decisions/0030-contacts-management.md) and
[package acceptance](../implementation/prs/pr-25.md#implementation-and-acceptance). With the pinned
toolchain selected per [setup](setup.md), stage intended files and run:

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Tests exercise three approved operations, independent write/read/subset/Google policy, observation
without mutation authority, exact before/after fields, hidden/unified/foreign/stale records, deletion
checkbox plus exact phrase, no-op/notes rejection, expiry/revocation/replay, unrelated native field
preservation, restricted postal fidelity, durable intent before dispatch, mismatched/lost receipts,
restart containment and cancellation before/after acceptance. Private temporary SQLite fixtures
are synthetic and cleaned up; in-memory CNMutableContact tests never initialize a real store.

The synthetic helper now exposes 18 tools. Both wire profiles exercise proposal/commit and forged
approval rejection; the helper returns notApproved because it has no native confirmation bridge.
[Official SDK checks](mcp-foundation.md#supplemental-official-sdk-interoperability) run independently
with legacy 1.26.0 and modern 2.4.0 pinned/automatic profiles. No client settings are changed.

For unsigned native presentation inspection, open Connections and the Sample Contact approval.
Inspect update fields and cancel; deletion must stay disabled until its checkbox and `DELETE` are
provided. Confirming this explicitly labeled fixed sample changes memory only. Quit afterward.
Do not enable Contacts, request permission, use personal records or execute the gated native backend.

Live acceptance remains engineering-owned: approved signing, peer/native review, writable scoped
container binding, minimum OS/home Mac and explicitly authorized isolated account fixtures. Verify
linked-record effects, account moves, provider errors, current permissions and last-writer-wins
limitations before changing the factory gate. Notes, structured postal wire input, unsupported postal
components, and recovery/retention retain explicit ADR triggers. Local/hosted passes prove neither
real writes nor Apple approval or release readiness.
