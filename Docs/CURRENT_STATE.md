# Current state

Updated: 2026-10-23. Work package: PR-01, repository foundation.

[GitHub PR #1](https://github.com/christianzbox/MacHandle/pull/1) is open for review.
Nothing has been merged or published. Active branch:
`codex/pr-01-repository-foundation`. Continue this PR from either Mac; do not create
a replacement branch or start PR-02.

## Implemented

Minimal native SwiftUI development window; local Swift package for presentation
metadata; synthetic Swift resource/linkage smoke test; privacy-checker regression
tests; Xcode Debug/Release build configuration with sandbox/hardened-runtime
settings; documentation and credential-free CI. No external runtime dependencies.
The supplied v5.0 master specification is preserved byte-for-byte.

PR-01 workflow addition: [work/home development and handoff](DEVELOPMENT.md), exact
`Config/Toolchain.env` baseline, portable preflight with drift rejection, shared
Codex instruction discovery, and CI validation from a fresh path containing spaces.
[ADR-0002](ADR/0002-portable-development.md) records this supplemental requirement.

## Validation

Shared baseline: **Xcode 27.1 (27A9275), Swift 6.4, macOS SDK 27.0**.
Standard commands: `bash Scripts/check_environment.sh`, `bash Scripts/validate.sh`,
and `bash Scripts/scan_secrets.sh`. See [testing](TESTING.md).

The prior foundation head `3a13185d9825051d3385a9b651934a6924cce66a` passed both
[hosted checks](https://github.com/christianzbox/MacHandle/actions/runs/39985663775).
That run used Xcode 26.6, not the new baseline. The portability update must pass
its own latest-head CI on `xcode-27`; consult PR #1's checks. GitHub labels that
runner preview; its availability is a CI dependency, while the exact Xcode
version/build is enforced independently of the runner's default or beta installs.

Work Mac: macOS 27.0.1, Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0: matches the
new baseline. The original Xcode 26.6 host support excluded macOS 27, motivating
the deliberate baseline update in ADR-0002. Current suite: 1 Swift harness test plus 12
Python regression tests (privacy/index protection and environment selection).
Local strict validation passed: Debug/Release builds, analyze action, Swift
formatting, all 13 tests (1 Swift + 12 Python), indexed-file checks, and secret
scans. No detected secrets; master-spec bytes and original license are unchanged.
Synthetic preflight tests do not prove a real second-machine installation.

The home Mac has not been accessed or validated. On each Mac install/select the
baseline, run standard validation, and record its result. All build dependencies
are in the clone or documented tools; no secrets or signing identities are needed.

## Repository inspection

Existing public `christianzbox/MacHandle`, default `main`, clean initial commit
`2429cc2`; Apache-2.0 license preserved. GitHub CLI authenticated with repository
and workflow access. Squash-only merges, auto-delete branches, auto-merge disabled.
Active main ruleset 25734616: PR required, zero approvals, conversation resolution,
linear history, block force pushes/deletions, no bypass actors. Secret scanning
and push protection enabled. After both jobs succeeded, the ruleset was updated
to require the observed `Build and test` and `Secret scan` checks from the GitHub
Actions app (15368), with the branch required to be up to date. A comparison of
before/after settings verified all existing rules, conditions, and bypass settings
were preserved.

## Limitations and risks

No Apple data, OAuth, synchronization, MCP, Reminders, Contacts, Notes, policy
engine, persistence, approvals, or complete product UI. No connected services.
No launch/UI automation, sandbox runtime, minimum-OS, live-provider, signing,
notarization, or public release proof. Unsigned builds cannot validate enforcement
of signing-dependent protections. Scanner success is not a privacy/security guarantee.

macOS 14 deployment floor and development bundle ID are provisional under ADR-0001.
PR-02 must evaluate compatibility, sandbox/helper constraints, and distribution
identity. Toolchain updates must change the shared baseline deliberately on both
Macs and CI. The package
smoke test proves harness wiring only; behavioral coverage grows with real features.

## Next eligible work

The portability addition is implemented on the existing PR-01 branch. Inspect
its latest-head CI and leave the PR open for review. To resume,
fetch the branch, compare the PR head SHA, read DEVELOPMENT and ADR-0002, inspect
PR comments/checks, and continue only remaining PR-01 work. No prior chat is needed.
Only after its merge is verified, start a fresh session for [PR-02](PRs/PR-02.md).
Follow [PR_PLAN](PR_PLAN.md); never treat an open PR as completed prerequisites.
