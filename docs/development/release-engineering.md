# Release engineering and local rehearsal

Work package 30 implements an **unsigned development packaging rehearsal**, not a release pipeline.
No Developer ID identity, production bundle ID, notarization credential or publication authorization
is configured. The production factory and [audit gates](diagnostics-security-audit.md) stay closed.
[ADR-0034](../architecture/decisions/0034-release-engineering-readiness.md) owns this decision.

## Run the local rehearsal

Use a clean committed checkout and the pinned toolchain. No account, signing key, network upload or
installed application is needed. Choose a new output directory whose parent already exists, outside
Git/cloud-sync folders. Do not use personal data to test the result.

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
bash Scripts/package_development.sh /tmp/machandle-development-rehearsal
python3 Scripts/release_artifact.py verify /tmp/machandle-development-rehearsal
# Expected exit 2: development packaging must never satisfy the distribution gate.
python3 Scripts/release_artifact.py verify /tmp/machandle-development-rehearsal --require-distributable
```

The script refuses dirty tracked/untracked state and an existing destination. Ignored files are
excluded by a Git archive of the exact recorded HEAD. It builds Release in a fresh temporary source/
derived-data directory, with signing and provisioning updates disabled, using one host architecture.
The build is never launched. Temporary sources/build logs are removed on exit; failures print a
fixed message. Reproduce build failures with the normal local validation command; do not upload raw
logs. Existing output is never overwritten. The private output directory contains:

| File | Meaning |
| --- | --- |
| `MacHandle-development.zip` | Only the current app executable, Info.plist and PkgInfo, with executable mode retained |
| `manifest.json` | Exact source SHA, observed bundle/version/minimum OS/native architecture, per-file/archive SHA-256 and explicit unverified signing/notarization/development status |
| `SHA256SUMS` | SHA-256 for the ZIP and manifest; verify again after transfer |

ZIP timestamps/modes are normalized, with no filesystem extended attributes or extra archive members.
The same input bytes produce the same package on the same Python/zlib toolchain; clean Xcode rebuilds
are **not claimed byte-reproducible**. Binary compiler metadata may include build paths; the manifest
does not collect user/machine paths or credentials. File allowlisting is not proof that a binary or
plist contains no secret: review source, run scans and inspect artifacts before any sharing.

The validator checks exact bundle paths, regular files, size limits, metadata identity/version,
minimum OS, a thin Mach-O executable header and archive/member hashes. It rejects links, hardlinks,
unexpected files/directories, duplicate/traversal members, metadata changes and forged release flags.
It reads archive members without extraction. It does not authenticate the author, attest a build,
prove executable behavior, verify signing or contact Apple. A checksum supplied with an artifact
protects against accidental corruption; an attacker can replace both. The low-level `create` helper
accepts an asserted source SHA; use the clean-source wrapper for an actual build record. Neither is
cryptographic provenance. The artifact is local rehearsal evidence only, never a public download.

Current output is host architecture only (arm64 here; x86_64 needs its own run). The app's minimum
OS remains macOS 14; compiling for it does not prove runtime compatibility. The standalone synthetic
stdio helper is deliberately not bundled or installed. Adding resources/frameworks/helpers or a
production identity requires a reviewed packaging profile; do not broaden the allowlist to pass.

## Account and credential preparation

See [account setup](account-release-checklist.md). The maintainer decides when to register/enroll and
creates credentials locally. No setup is needed to run the commands above. Never put private keys,
certificate exports, passwords, API keys, OAuth secrets or personal profiles in Git, PRs or logs.
There is no release credential in normal CI and no auto-publishing workflow.

## Future Developer ID / notarization workflow — not executed or enabled

This is the operator runbook for the blocked production track. Each stage needs the gate evidence
below and separate maintainer authorization. Do not apply it to a rehearsal ZIP or this development
identity. Prefer Xcode's Archive → Distribute App → Developer ID workflow after the production target,
identity and signed packaging profile have been reviewed. Keep private credentials in Keychain.

1. Freeze the intended supported capability set and source commit; validate both locally and in
   hosted CI. Obtain the maintainer's approved production bundle ID/team and Developer ID Application
   identity. Retain development/production Keychain and container separation. Do not infer ownership
   from a bundle string or change the current development ID merely to make an archive export.
2. Implement/review the production archive/export configuration for that identity. Sign every shipped
   executable correctly, including any future helper, with hardened runtime and secure timestamp.
   Do not use `--deep` to apply signatures or add blanket runtime exceptions. No `get-task-allow` in
   distribution entitlements. Confirm that actual entitlements match the reviewed capability set.
3. Inspect the resulting signed app, separately from a successful compiler build. Representative
   **read-only checks for that future artifact** are:

   ```sh
   codesign --verify --deep --strict --verbose=2 "$MACHANDLE_SIGNED_APP"
   codesign --display --verbose=4 "$MACHANDLE_SIGNED_APP"
   codesign --display --entitlements :- "$MACHANDLE_SIGNED_APP"
   ```

   Check the actual Developer ID Application authority, expected team/bundle identifier, runtime flag,
   timestamp and entitlements. An ad-hoc/Apple Development signature is not Developer ID proof.
4. After explicit upload authorization, submit the signed artifact using Xcode or `xcrun notarytool`
   with a locally stored Keychain profile. Check accepted status **and** the notary log for warnings;
   never print credential arguments. `altool` is not the supported submission path. This repository
   intentionally supplies no upload command, secret input or unattended credentials workflow yet.
5. Staple the accepted ticket to the app, validate it, then create the final distribution archive.
   A ZIP cannot be stapled directly; any pre-staple archive/checksum must be replaced. Read-only
   checks include `xcrun stapler validate "$MACHANDLE_SIGNED_APP"` and
   `spctl --assess --type execute --verbose=4 "$MACHANDLE_SIGNED_APP"`. Reassess the exact delivered
   bytes on a separate Gatekeeper-enabled Mac, including offline ticket availability. Never bypass
   quarantine or disable Gatekeeper to manufacture a pass.
6. Complete isolated synthetic-account install/upgrade/permission/Keychain/login/helper/revocation/
   recovery tests, advertised architecture/minimum-OS matrix, accessibility and resource gates.
   Notarization is not App Review, functional acceptance or a security audit.
7. Generate final signed-artifact checksums/provenance and a capability-accurate changelog. Only then,
   with separate approval, create a **draft** GitHub Release tied to the validated commit/tag. Review
   attached final bytes and independently verify hashes. Publish only after explicit authorization;
   do not reuse the development rehearsal manifest as signing evidence. No draft/tag/release is
   created by this package.

These steps follow Apple's [notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[custom workflow/stapling guidance](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
and [Developer ID certificate roles](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/),
checked 2026-10-29. Recheck requirements when the signed track is authorized.

## Owned release gates

All rows remain open. Passing rehearsal verification cannot close them.

| Gate | Required evidence | Owner / revisit trigger |
| --- | --- | --- |
| P1 Identity/credentials | Approved stable production namespace/team, enrollment, signing-key custody and local notary credential; no private values in repository | Maintainer; when choosing to enroll and authorize signed acceptance |
| P2 Signed packaging | Reviewed production archive/export/helper layout, actual Developer ID/timestamp/runtime/entitlements, signature checks, accepted notary log, stapled final bytes, clean-Mac Gatekeeper proof | Engineering + maintainer; after P1, before any distribution |
| P3 Advertised services | Audit G1–G4; isolated signed permissions/export denial, IPC/pairing, Keychain continuity, real supported provider reads/recovery and exact-write conflict gates | Engineering; isolated accounts and user-authorized live testing |
| P4 Compatibility/UX | Advertised architecture/minimum-OS and current-OS install/upgrade/uninstall; full accessibility, resource/lifecycle and second-Mac evidence | Engineering + maintainer; signed candidate ready |
| P5 Publication/update | Version/tag/changelog/checksums/provenance reviewed, secure manual update/rollback, private security reporting verified, explicit release approval | Maintainer; after supported-scope P1–P4 evidence |
| Conditional integrations | Notes G1–G6 and remote R1–R6; actual platform compatibility before plugin claims | Existing engineering/maintainer owners; isolated setup/platform support; exclude unsupported capabilities from release promises |

No legal entity or D-U-N-S number is required just to keep developing. Organization enrollment is
optional; choose it only if that is the intended ownership model. A future genuinely limited release
may exclude Notes/remote, but cannot waive safety evidence for anything it advertises.
