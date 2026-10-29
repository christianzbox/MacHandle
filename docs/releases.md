# Release policy

No installable public release exists. The development bundle is not Developer ID verified or
notarized; do not distribute it as a production application or ask users to disable Gatekeeper.
Work package 30 provides a local [packaging rehearsal](development/release-engineering.md),
[account checklist](development/account-release-checklist.md) and blocked production runbook.
It does not create accounts, sign/notarize/upload binaries, create tags/releases or enable services.

## Channels and compatibility

Use semantic versioning for future public releases. The current 0.1.0/build 1 and
`org.machandle.development` are development values, not release identity or an announcement.
Current rehearsal ZIPs contain one host architecture, record their source SHA and target macOS 14.
Minimum-OS/Intel/second-Mac runtime support remains unverified. No universal binary, installer,
packaged MCP helper, automatic updater, Notes capability or remote/plugin compatibility is promised.
An eventual limited release may exclude unsupported integrations; it must verify every advertised
capability and clearly separate development, isolated test and production identities/data.

## Install and first run

Today, use the [source setup instructions](development/setup.md) on the development Mac. Rehearsal
artifacts are local engineering evidence; they are not an installation recommendation. Synthetic
validation and packaging never require Apple resource permission or personal iCloud test data.

For a future approved release, obtain the exact artifact from the official repository's release,
verify its checksum against the reviewed release evidence and verify Developer ID/notary/Gatekeeper
acceptance on the final bytes. Follow that release's installation instructions; a future ZIP app
would be moved to Applications only after these checks. An unexpected signature/identity warning is
a stop condition, not a reason to strip quarantine. Start with all connections off; separately opt
into each advertised service and resource selection. Use isolated synthetic accounts for acceptance.

## Manual update and rollback policy

No background updater or update feed is implemented. Future updates will initially be deliberate
manual downloads with version/changelog, source commit, supported architecture/OS, checksum and
signed artifact evidence. Pause/drain work and quit before replacing an installed app. Verify signing
identity, entitlements, Keychain/container continuity and data migration on an isolated test profile
before a release is offered. Do not treat a preserved bundle ID as proof of credential continuity.

Do not downgrade a live database blindly. Preserve private recovery metadata locally and follow the
[recovery procedure](development/sync-recovery.md); pending/unknown operations require verification,
not replay, deletion or automatic reset. A rollback is allowed only with documented compatible schema,
identity and restored-state acceptance for that version. Otherwise stop synchronization and obtain a
reviewed migration/recovery plan. No account data backup/export or deletion is performed by packaging.

## Uninstall and credential continuity

For a future activated build, pause/disconnect through the app and disable login before quitting and
removing it. Removing the app must not be represented as deleting cloud copies, revoking Google
grants or erasing Keychain/container data. Grant revocation is separate and may affect other
installations. Do not manually delete journals to clear an error. Retain explicit cleanup/retention
instructions and test uninstall/reinstall and certificate renewal before claiming support.

## Distribution and security gates

The [P1–P5 ledger](development/release-engineering.md#owned-release-gates) owns identity, signed/notarized
packaging, provider/audit, compatibility/UX and publication acceptance. All remain open; Notes/remote
retain their separate conditional gates. [Security reporting](../SECURITY.md) and [privacy](../PRIVACY.md)
apply to source and artifacts. Scanners/checksums are not certification or authentication.

Before a future GitHub Release, verify the exact final source and artifact, both hosted checks,
capability-specific acceptance, signing/notary logs and final checksums. Prepare a reviewed draft
with release notes and only final artifact bytes. Publishing, signing, uploading and account actions
require separate maintainer authorization. Ordinary PR CI stays read-only and receives no release
credentials; no release automation is enabled in this package. Record unsupported features and owned
deferrals rather than marking all milestones complete.
