# ADR-0034: Development packaging and blocked production distribution

Date: 2026-10-29. Status: implemented for work package 30 review; production release deferred.

## Context and evidence

GitHub PR #30 merged work package 29's scoped audit. The maintainer has no established production
identity/signing setup and does not intend to publish yet. Audit G1–G4, signed/provider acceptance,
Notes G1–G6 and remote R1–R6 remain open. The current Release app has only an executable, Info.plist
and PkgInfo, uses `org.machandle.development` and does not ship the synthetic stdio helper.

Apple requires actual Developer ID signing, hardened runtime/timestamp and notarization evidence
for the intended direct-distribution track; notarization is not App Review. The dated official
sources and exact future workflow are in [release engineering](../../development/release-engineering.md).
Local packaging can be exercised without enrollment, credentials, personal data or public artifacts.

## Decision

Provide a clean-committed-source local packaging wrapper and closed development artifact profile.
Git archive excludes ignored/untracked machine state. Fresh temporary Release builds disable signing,
provisioning updates and app launch. One host architecture is recorded explicitly. The wrapper does
not package the repository, developer home, stale DerivedData or standalone helper.

The Python standard-library validator admits only the three reviewed bundle files, bounded regular
files, expected metadata/minimum OS and thin native executable header. It rejects links, hardlinks,
unexpected directories/files and unsafe/duplicate ZIP members. ZIP modes/timestamps are normalized;
per-file/archive hashes, exact commit assertion and explicit development status accompany the output.
Verification never extracts/runs the archive. Existing output is not overwritten. The distribution
check exits 2 even for a valid rehearsal; falsified status fields cannot make it pass. Checksums are
integrity evidence, not authenticity or signed build attestation. Binary/privacy review is still needed.

No production signing configuration, credentials workflow, upload, release job or elevated CI token
is added. Document the Developer ID/notarization/install/update/security runbook and P1–P5 owners;
implement/test the signed profile only after identity/setup and separate authorization. No guessed
team, claimed production identifier or secret is committed. Current domain/app/provider behavior,
permissions, entitlements, CI credential policy and toolchain remain unchanged.

## Alternatives, constraints and consequences

- Packaging an existing build folder is fast but can attribute stale output to the wrong revision;
  prefer fresh source/archive builds. The low-level helper remains internal tooling, not attestation.
- A broad recursive ZIP could capture exports or private files. A closed profile deliberately fails
  when future resources/frameworks/helpers are added, requiring review rather than silent inclusion.
- Signing/upload automation now would be untested and invite accidental release. Prefer an explicit
  blocked runbook and credential-free tests. A future manually gated pipeline needs its own review.
- DMG/installer/universal binaries add formats/platform claims without evidence. Defer to P2/P4;
  ZIP rehearsal establishes neither quarantine behavior nor installer/signature compatibility.
- Do not release a feature merely because its source exists. Define a supported capability subset;
  Notes/remote may remain excluded, while safety gates for advertised features remain mandatory.

## Verification and owned deferrals

Synthetic tests cover integrity, modes, tampering, forged status, private/extra files, links, limits,
metadata/architecture rejection and existing-output preservation. A hardlink metadata check is
simulated where macOS prevents creating app-bundle hardlinks. Clean-source packaging and negative
wrapper/distribution checks are recorded in [acceptance](../../implementation/prs/pr-30.md#implementation-and-acceptance).
Full repository gates run separately; packaging does not replace them or prove production behavior.

P1–P5 in the [gate ledger](../../development/release-engineering.md#owned-release-gates) retain owners,
requirements and triggers for credentials, signed package/notary/Gatekeeper, live services,
architecture/OS/UX and publication. Engineering owns implementation/verification; maintainer owns
identity/account choices and explicit signing/upload/release authorization. No public release exists.
