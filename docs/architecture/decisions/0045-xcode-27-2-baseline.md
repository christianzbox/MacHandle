# ADR-0045: Shared Xcode baseline follows hosted availability

Date: 2026-10-30; revised 2026-11-03. Status: implemented for review; exact-revision validation evidence in PR #41.

## Context and decision

The initial decision in this PR pinned the locally installed Xcode 27.2 release
(27B52), Swift 6.4.2 and SDK 27.2. GitHub's image only included the earlier 27.2
release candidate (27B48), so the exact hosted preflight failed. Local success
could not establish hosted parity. That proposed upgrade is superseded below;
the ADR path remains stable for existing references.

The maintainer now authorizes installing Xcode 27.1 alongside 27.2 and choosing
the shared baseline from versions already preinstalled on GitHub. Restore
Xcode 27.1 build 27A9275, Apple Swift 6.4 and macOS SDK 27.0 in
Config/Toolchain.env. This retains ADR-0002's exact checks, per-process selection,
clean checkout and no-global-selection requirements. No application deployment
target, Swift language mode or test coverage changes.

Local scripts already discover an exact matching Xcode among installed versions.
Keep newer versions alongside the baseline; use DEVELOPER_DIR for custom paths.
An App Store upgrade does not change the project requirement. CI uses its
preinstalled toolchain, with no Xcode download, cache, Apple credentials, private
archive storage or self-hosted runner.

## Upgrade procedure and ownership

Engineering verifies the exact intended release build is preinstalled on the
chosen runner and supported by both development Macs before changing the pin.
Update Config/Toolchain.env, setup/testing guidance and decision evidence in one
reviewed PR. Install/select it locally with maintainer authorization, execute all
three strict local gates, then mark ready for both full hosted checks. Record the
exact revision and results. This is a deliberate upgrade, not a per-job install.

Recheck availability on upgrades or a preflight failure. If the image removes the
pinned build, keep the PR draft while selecting and validating a supported
replacement. Do not weaken the exact check or repeatedly retry known drift.

## Alternatives and tradeoffs

- Side-by-side local Xcode costs disk space and a one-time download per upgrade,
  but avoids recurring hosted download/install time and credential maintenance.
- Keeping 27.2 as the required baseline would leave this PR blocked until GitHub
  ships 27B52. Its availability is not yet established.
- Installing a downloaded Xcode in each hosted job is feasible, but adds startup
  time and authenticated archive delivery. The maintainer selected the simpler
  preinstalled baseline instead.
- Accepting the hosted 27.2 release candidate would hide a real build/compiler/SDK
  difference. Exact baseline validation remains mandatory.

## Verification and limits

On 2026-11-03 the official xcode-27 inventory includes 27.1 build 27A9275 and
27.2 RC build 27B48. The earlier successful run 41127791583 used 27.1; it is
historical evidence only. Final strict local and hosted results belong on GitHub
PR #41. Local 27.1 installation and exact preflight are verified alongside 27.2;
keep the PR draft until all local gates complete.
The other development Mac remains unverified. No merge or live-provider
acceptance is implied by local builds, inventory availability or CI success.

References: [runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md),
[Apple system requirements](https://developer.apple.com/xcode/system-requirements),
[ADR-0002](0002-portable-development.md), [testing](../../development/testing.md).
