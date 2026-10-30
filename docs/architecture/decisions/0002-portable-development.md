# ADR-0002: Interchangeable development Macs

Date: 2026-10-23. Status: accepted for PR-01 workflow extension.

The version tuple below is historical: [ADR-0045](0045-xcode-27-2-baseline.md)
updates it to Xcode 27.2 (27B52), Swift 6.4.2 and SDK 27.2. Strict validation and
per-process discovery remain in force; hosted availability is explicitly pending.

## Context and decision

Work and home MacBooks must independently clone, build, test, and resume the same
feature branch. They are equally supported development environments; neither
checkout, local Codex conversation, credential store, nor shell profile is a
project dependency. This extends PR-01 rather than starting PR-02.

Use `Config/Toolchain.env` for exact Xcode version/build, bundled Swift, and SDK.
Adopt Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0 for both Macs and CI. The original
26.6 CI baseline is not appropriate for the work Mac's macOS 27.0.1: Apple's host
support table limits Xcode 26.6 to macOS 26.x, while Xcode 27.1 supports macOS 26.6
or later. This is a host compatibility decision, not just preference for the
installed version. GitHub's `xcode-27` runner lists the exact same 27.1 build.

The standard preflight fails on drift; a clearly labeled local-only override
permits compatibility tests but never substitutes for baseline CI. This supersedes
ADR-0001's permissive local toolchain selection and original CI baseline. The app's
macOS deployment floor is unchanged. GitHub labels the `xcode-27` image preview;
record that availability risk, require CI success, and never silently fall back
to the default 27.0 or installed 27.2 beta. An RC-named installation directory in
the inventory is not how we select a toolchain; exact version/build identity is.

Select Xcode per process through discovery or an explicit local DEVELOPER_DIR.
Use repository-relative scripts and shared project/scheme/package files, no
per-user checkout paths or global setup mutations. CI uses a fresh checkout whose
path contains spaces and runs the same standard command as both Macs. No build
cache, signing team, secret, database, or remote service is needed to validate.

Select and export the developer directory before probing bundled Python or Git.
Apple's launchers also depend on that selection; probing Python first could fail
before discovery repairs an unusable global selection. A synthetic regression
test covers this ordering without changing the host's global Xcode setting.

Keep build-tool versions exact and general-purpose utility versions compatible.
Do not add a package manager or container just to install already bundled tools.
Commit lockfiles when third-party packages are actually introduced. This provides
repeatable configuration and validation, not bit-for-bit artifact reproducibility.

Use commit/push and the existing PR for machine handoff. Store active context and
next steps in progress and PR coordination, brief/ADR decisions in Git, and reviews/checks in
GitHub. Prefer fast-forward pulls and one active writer; never force-push away the
other Mac's work. Root AGENTS and minimal project Codex config are shared; trust,
authentication, model choice, and local permissions remain per-machine.

## Alternatives, tradeoffs and consequences

- Letting each Mac use its newest Xcode reduces setup work but hides compiler/SDK
  drift. Exact baseline checks make differences explicit; upgrades must update
  configuration, CI evidence and both development setups together.
- Keeping Xcode 26.6 would retain the initial stable runner but conflicts with the
  work Mac's supported host versions. Xcode 27.1 meets that host constraint at the
  cost of a preview CI image dependency; verify runner availability on every PR.
- Copying a working directory/caches or synchronizing personal Codex state would
  hide missing dependencies and expose private machine configuration. A fresh clone
  and pushed branch need a separate sign-in and tool installation on each Mac, but
  preserve reviewable source and avoid a privileged primary development machine.
- A project generator or container adds tooling without replacing Xcode's native
  SDK/build requirements. Retain the small checked-in project and shared scheme;
  review deliberate configuration changes as the app grows.

## Evidence and limits

Baseline tuple verified on the work Mac: Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0.
The previous [CI run 39985663775](https://github.com/christianzbox/MacHandle/actions/runs/39985663775)
used 26.6 and cannot prove the new baseline. The subsequent
[27.1 CI run](https://github.com/christianzbox/MacHandle/actions/runs/39988488252)
verified the exact tuple at `d2aed09`; see [progress](../../implementation/progress.md).
The home Mac has not been accessed. New preflight tests use synthetic executables
to check mismatch rejection, explicit paths/spaces, discovery, and CI override
rejection; they are not evidence of installing or running on a second physical Mac.

References: [Apple host requirements](https://developer.apple.com/xcode/system-requirements),
[GitHub xcode-27 inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).
See [development setup and handoff](../../development/setup.md) for tools, commands, and the
fresh-session prompt. No product permissions, integrations, or release milestones
change as part of this decision.

## CI cadence follow-up

[ADR-0044](0044-local-validation-ready-pr-ci.md) changes when hosted checks run:
full local validation during development, full hosted checks on ready PRs, and no
duplicate main-push run. The exact baseline and clean-checkout requirements above
remain unchanged. Historical work-Mac evidence does not prove its current setup.
