# ADR-0001: Minimal native foundation

Date: 2026-10-23. Status: accepted for PR-01; deployment/release decisions provisional.

## Decision

Use SwiftUI for the app, a checked-in Xcode project with a shared scheme, and a
local Swift Package Manager library/test target. Use Swift 6 language mode and a
Swift tools 6.2 manifest. There are no third-party app dependencies or generated
project tools. Toolchain patch versions are recorded with validation results.

Set macOS 14.0 as a provisional deployment floor: the planned EventKit access
model and native application direction motivate this baseline, rather than the
OS of the development machine. PR-02 must validate actual API availability,
sandbox feasibility, and runtime compatibility on the oldest supported OS.
A successful deployment-target build is not an oldest-OS runtime test.

Use a placeholder development bundle ID `org.machandle.development`. Select a
stable owned distribution ID and Keychain access strategy before credentials or
shipping builds are introduced. Do not casually change those after release.

Enable App Sandbox and hardened runtime with no data/network entitlements in the
foundation. CI disables signing solely to build without private credentials.
PR-02 must assess helper/MCP/Automation constraints; do not disable sandboxing
silently when future integration encounters a constraint.

Initial CI used `macos-26` with Xcode 26.6; initial local validation used Xcode
27.1 / Swift 6.4. [ADR-0002](0002-portable-development.md) now supersedes permissive
local selection: both Macs and CI use the exact tuple in `Config/Toolchain.env`.
Newer-toolchain checks are supplemental only. The manifest floor does not mean
every intervening toolchain is tested.

## Alternatives and consequences

A package-only executable would not exercise normal app bundle configuration.
Generating a project would add unnecessary tooling. A checked-in small project
supports native development and credential-free builds now; it needs deliberate
maintenance as targets evolve. Do not pre-create all future modules.

## References

- [Apple EventKit access](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)
- [GitHub macOS 26 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
- [Swift package documentation](https://www.swift.org/documentation/)
