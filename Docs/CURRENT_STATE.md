# Current state

Updated: 2026-10-23. Work package: PR-01, repository foundation.

## Implemented

Minimal native SwiftUI development window; local Swift package for presentation
metadata; synthetic Swift resource/linkage smoke test; privacy-checker regression
tests; Xcode Debug/Release build configuration with sandbox/hardened-runtime
settings; documentation and credential-free CI. No external runtime dependencies.
The supplied v5.0 master specification is preserved byte-for-byte.

## Validation

Local: Xcode 27.1 (27A9275), Swift 6.4, macOS SDK 27.0, Apple Silicon.
The globally selected command-line tools differ; scripts select Xcode per process.
Local validation passed: Swift package build, 1 Swift smoke test, formatting,
Xcode Debug/Release builds and analyze action, 6 privacy-checker regression tests,
indexed-file privacy checks, whitespace checks, and Gitleaks history/index scans.
No detected secrets; manual review found no private material in the staged files.
Master-spec byte equality and unchanged LICENSE verified. Hosted CI is pending.
CI baseline is macos-26 / Xcode 26.6; local success does not establish hosted parity.

Commands: `bash Scripts/validate.sh` and `bash Scripts/scan_secrets.sh`.
See [testing](TESTING.md) for checks and evidence limits.

## Repository inspection

Existing public `christianzbox/MacHandle`, default `main`, clean initial commit
`2429cc2`; Apache-2.0 license preserved. GitHub CLI authenticated with repository
and workflow access. Squash-only merges, auto-delete branches, auto-merge disabled.
Active main ruleset 25734616: PR required, zero approvals, conversation resolution,
linear history, block force pushes/deletions, no bypass actors. Secret scanning
and push protection enabled. Required CI checks will be added only after names
are observed in actual runs; do not guess names or remove existing rules.

## Limitations and risks

No Apple data, OAuth, synchronization, MCP, Reminders, Contacts, Notes, policy
engine, persistence, approvals, or complete product UI. No connected services.
No launch/UI automation, sandbox runtime, minimum-OS, live-provider, signing,
notarization, or public release proof. Unsigned builds cannot validate enforcement
of signing-dependent protections. Scanner success is not a privacy/security guarantee.

macOS 14 deployment floor and development bundle ID are provisional under ADR-0001.
PR-02 must evaluate compatibility, sandbox/helper constraints, and distribution
identity. CI toolchain availability may drift and must be maintained. The package
smoke test proves harness wiring only; behavioral coverage grows with real features.

## Next eligible work

Open PR-01 against main, verify hosted CI and required checks, then stop for user review.
Only after its merge is verified, start a fresh session for [PR-02](PRs/PR-02.md).
Follow [PR_PLAN](PR_PLAN.md); never treat an open PR as completed prerequisites.
