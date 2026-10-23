# Validation and evidence

## Local commands

Full Xcode is required (Xcode 26.6 is the CI baseline; Swift tools 6.2 or newer).
Select an installed Xcode per command with `DEVELOPER_DIR`; no global change is
necessary. Python 3 is used only for repository checks, never as an app daemon.
`curl`, `shasum`, Git, and internet access are needed for the pinned secret scanner.

Stage intended changes before running checks so privacy/secret checks cover new
files. Review `git diff --cached` and make sure the index matches intended sources.

```sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

`validate.sh` runs Swift formatting lint, warnings-as-errors package build/test,
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
No EventKit, OAuth, sync, MCP, UI automation, or real-account coverage is claimed.

## Hosted CI

`.github/workflows/ci.yml` is authoritative:

| Check | Environment | Command |
| --- | --- | --- |
| Build and test | macos-26, Xcode 26.6 | `bash Scripts/validate.sh` |
| Secret scan | ubuntu-24.04, Gitleaks 8.30.1 | `bash Scripts/scan_secrets.sh` |

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
