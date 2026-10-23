# Validation and evidence

## Local commands

Full Xcode 27.1 (27A9275), Swift 6.4, and SDK 27.0 are required by
`Config/Toolchain.env` on both Macs and CI. `check_environment.sh` verifies them
and selects matching Xcode per process; `DEVELOPER_DIR` selects a custom location.
See [development setup](DEVELOPMENT.md); no global selection change is necessary. Python 3 is used only for repository checks, never as an app daemon.
`curl`, `shasum`, Git, and internet access are needed for the pinned secret scanner.

Stage intended changes before running checks so privacy/secret checks cover new
files. Review `git diff --cached` and make sure the index matches intended sources.

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

`validate.sh` first runs the strict toolchain preflight, then Swift formatting lint, warnings-as-errors package build/test,
unsigned Xcode Debug build/analysis and Release build, privacy-checker regression
tests, indexed-file privacy checks, and whitespace checks. Xcode's analyze action
is supplemental; this all-Swift skeleton does not have a dedicated semantic
security analyzer. Swift compilation/concurrency checking is the primary static
analysis today. No CodeQL coverage is claimed.

`scan_secrets.sh` downloads Gitleaks 8.30.1, verifies an embedded SHA-256 archive
hash, and scans all fetched Git history plus the exact index. Output is redacted.
It does not scan ignored local files or prove absence of private information.
Release archives/hashes come from [upstream](https://github.com/gitleaks/gitleaks/releases/tag/v8.30.1).
Do not add broad scanner exclusions to suppress a real leak. Revoke leaked secrets
and handle history separately; deleting the current file is insufficient.

Swift smoke coverage tests package linkage and bundled synthetic resource loading.
Python regression tests cover prohibited exports/databases/credentials, misleading
extensions, binary files, symlinks, fixture declarations, and valid source files.
Preflight regression tests use synthetic executables to verify custom paths with
spaces, mismatch rejection for Xcode/build/Swift/SDK, missing-Xcode diagnostics,
and rejection of compatibility overrides in CI. They do not prove a real Xcode
installation. No EventKit, OAuth, sync, MCP, UI automation, or real-account coverage
is claimed.

If baseline Xcode is unavailable locally, `bash Scripts/validate.sh
--allow-toolchain-mismatch` (on one shell line) runs supplemental checks and prints
that limitation. CI rejects this override. Report strict baseline validation as
blocked locally until the matching Xcode is installed; never call compatibility
results baseline parity. This prevents one Mac's toolchain drifting silently.

## Hosted CI

`.github/workflows/ci.yml` is authoritative:

| Check | Environment | Command |
| --- | --- | --- |
| Build and test | xcode-27, Xcode 27.1 | `bash Scripts/validate.sh` |
| Secret scan | ubuntu-24.04, Gitleaks 8.30.1 | `bash Scripts/scan_secrets.sh` |

The build job uses a fresh checkout in `MacHandle clean checkout` (a path with
spaces), without transferred caches or a hard-coded developer directory. It runs
the same strict version check and commands as both Macs.

Both jobs run for every PR and push to main, without path filters or privileged
`pull_request_target`. There is no publishing workflow. Dependabot tracks GitHub
Actions; runtime dependency vulnerability scanning becomes necessary when runtime
dependencies are added. Currently the package has none.

After the first observed successful jobs, preserve all existing main rules while
adding their actual names as required status checks. Record repository settings
and hosted evidence in current state. Local success is separate from hosted
success, launch testing, sandbox validation, minimum-OS support, and notarization.

Build output stays in ignored `.build/`. Keep logs outside Git and do not attach
private diagnostic output to a public PR. See current state for this PR's evidence.
