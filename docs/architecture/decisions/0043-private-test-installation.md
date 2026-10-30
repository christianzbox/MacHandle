# ADR-0043: Reusable account-free private test installation

Date: 2026-10-30. Status: in progress; installation acceptance pending.
Prerequisite: GitHub PR #39 merged at `eb0002146b4efb5ae39c3f5e7131620c586fc102`.
Scope: [slot 6](../../implementation/prs/private-reminders-slot-6.md), specification §20–22 testing,
release safety and maintenance; no production distribution or live-provider activation.

## Decision

Build the two sample executables in Release from a Git archive of a clean, recorded HEAD using the
pinned toolchain. Package at its final owner-selected path outside the checkout; never replace a
destination. Copy the small launcher/runtime into that installation so later checkout changes cannot
silently alter it. Preserve the app/helper certificate, bundle identifier, installation UUID, service
and client entry name by reusing the same sealed package across sessions. Keep connection selection
and approval off on every launch; only operation evidence survives, not in-memory reminder contents.

Use the existing account-free local certificate route with a 365-day validity period for this reusable
sample-write build; short acceptance fixtures retain seven days. Delete the generated private key
and task-owned keychain. No signing-team lookup, permanent credential, trust-store change, notarization
or certificate renewal is added. Longer validity does not establish future OS compatibility. Failure
later requires retained evidence and a reviewed new build, not a trust bypass or journal reset.

The installation verifier checks exact regular-file inventory/hashes/modes, rejects links, checks
source/identity/profile metadata and sample-only purpose strings/entitlements, then verifies the signed
package and bound helper paths. Moving/copying to another path is unsupported. Hashes detect accidental
corruption, not malicious replacement of both files and manifest; this is not cryptographic build
attestation. The low-level creator accepts a source assertion; only the archive/build wrapper supplies
clean-source provenance. Rebuilds/signatures/identities are not byte-reproducible.

## Update and removal policy

No in-place binary update or journal migration is supported. Stop and inspect the previous installation
before preparing a reviewed sibling build; retain it and its journal, and require zero unresolved
operations. Never use a new fixture identity to claim an old unknown effect was resolved. Rollback
reopens the unchanged old package with fresh selection/pairing. Both builds start disabled. No auto-
update or OS login service is installed. User-owned client entries are preserved during cleanup.

Removing the task-owned install directory is separate from journal/container deletion. There is no
Library cleanup, Keychain cleanup of existing items, receipt rewrite or data-reset command. SIGKILL
cleanup remains targeted/manual as documented by slot 5. Stable identity means reuse of this build;
cross-version identity/key continuity remains explicitly unsupported, not silently claimed complete.

## Alternatives and consequences

- A new package per session loses identity continuity. Preserve the exact installation for repeated
  testing; verify same-package restart and durable journal inspection on the designated Mac.
- Retaining a signing private key would support a future in-place upgrade design but creates custody,
  backup/revocation and migration obligations. Defer that to engineering/maintainer when continued
  cross-version identity is required; no paid enrollment follows from that choice.
- Reusing a bundle ID with a new unrelated certificate or clearing a journal could conceal uncertainty.
  Use separate named builds and retained evidence; no migration/automatic rollback claim.
- Copying only the app or relying on checkout scripts breaks path/source stability. Freeze the small
  runtime and final path; rebuild locally on another Mac only after separate compatibility acceptance.

## Verification and finish line

Tests cover corruption, unexpected files/links, moved installs, resealed permission changes, identity
mismatch, unchanged repeat verification and lifetime restrictions. The native acceptance harness uses
one prebuilt Release installation twice, with fresh selection/pairing, exact approvals/readbacks,
replay/revocation checks and retained journal counts. Actual desktop proof remains separately recorded
in slot 5; the new first-session checklist is for maintainer acceptance, not a claim it already ran.

The [handoff](../../development/private-testing-handoff.md) states accounts/tools, permissions, setup,
pass/fail observations and cleanup. This completes the planned engineering sample track once reviewed
and verified; it does not complete real EventKit/TCC/conflict acceptance, Notes, Google, Calendar,
Contacts, other Macs, minimum OS, remote/scheduling or public release. Those retain their owners and
explicit revisit triggers. Scope the live-Reminders phase before authorizing further implementation.
