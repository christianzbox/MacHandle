# ADR-0045: Xcode 27.2 exact shared baseline

Date: 2026-10-30. Status: implemented for review; hosted availability pending.

## Context and decision

The maintainer explicitly requested upgrading the project to the installed Xcode
27.2 rather than installing 27.1 alongside it. Pin Xcode 27.2 build 27B52,
Apple Swift 6.4.2 and macOS SDK 27.2 in Config/Toolchain.env for both Macs and CI.
This supersedes ADR-0002's version tuple, not its strict checks, per-process
selection, clean checkout, or no-global-selection requirements. No application
minimum deployment target or Swift language mode changes.

The current Mac exposes that exact tuple. The preflight discovers its full Xcode
without changing the global Command Line Tools selection. No installation,
license acceptance, credentials or machine path needs to enter this PR.
All maintained tests and validation commands remain unchanged; local verification
must now run without --allow-toolchain-mismatch.

## Alternatives and tradeoffs

- Installing 27.1 alongside 27.2 would match previous hosted runs, but the maintainer
  selected the upgrade instead. No extra Xcode installation is performed.
- Accepting any 27.2 build would hide the distinction between the hosted RC
  (27B48) and local release (27B52). Retain exact build/compiler/SDK validation.
- Downloading Xcode during every hosted run adds substantial time, bandwidth and
  possible account setup. Retain the preinstalled runner and wait for the exact
  release build instead of adding that recurring cost or new credentials.

## Hosted gate and verification

On 2026-10-30, the official xcode-27 runner inventory lists 27.2 RC build 27B48,
27.1 build 27A9275, and 27.0 build 27A266a. It does not list required build 27B52.
The previously successful run 41127791583 used 27.1 and is not new-baseline proof.
Keep GitHub PR #41 draft; engineering owns rechecking hosted inventory when the
image updates, then running both full required checks on the final current head.
No compatibility override, false passing status, or weakened ruleset is allowed.
This is an explicit external prerequisite, not completed hosted parity.

Current-Mac strict test results and the exact revision belong in GitHub PR #41.
The other development Mac must select/install the same tuple before strict
validation; its setup remains unverified. Local success does not establish live
provider acceptance, byte-identical artifacts, or hosted success.

References: [runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md),
[Apple system requirements](https://developer.apple.com/xcode/system-requirements),
[ADR-0002](0002-portable-development.md), [testing](../../development/testing.md).
