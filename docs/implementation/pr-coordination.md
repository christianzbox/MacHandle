# PR coordination and home-Mac handoff

Updated: 2026-10-23, America/Detroit. This register owns active work and next action;
[progress](progress.md) owns scoped evidence. Use the
[setup/handoff guide](../development/setup.md) for environment/authentication and
Git divergence handling. Do not duplicate credentials or machine configuration.

## Active work

| Field | Current value |
| --- | --- |
| Work package | PR-02 — Technical Feasibility and Architecture Decisions only |
| Branch | `codex/pr-02-technical-feasibility` |
| GitHub PR | Pending first push/creation; replace this field before machine handoff |
| Base | `main`; fetched at `4364fb79676de22d07cb6e5c01738481aad1f7d5` before branching |
| Prerequisite | [PR #1](https://github.com/christianzbox/MacHandle/pull/1), verified squash-merged 2026-10-23 14:14:32 America/Detroit (18:14:32 UTC) |
| Actual PR-01 merge SHA | `4364fb79676de22d07cb6e5c01738481aad1f7d5` |
| Pushed PR-02 checkpoint | Pending first commit/push; no unpushed checkpoint is a completed handoff |
| Writer | Current work-Mac session until checkpoint is pushed; then stop, one active writer only |
| Next action | Validate and open PR-02 for user review; no PR-03 implementation |
| Merge/release owner | User only; no merge, auto-merge or publication authorized |

PR numbering is the roadmap's work-package ID, not necessarily the GitHub PR number.
GitHub #2 is an unrelated dependency update. Never resume PR-01's deleted remote
branch for this work or push bookkeeping directly to main.

## Completed decisions and remaining gates

PR-01 merge bookkeeping is recorded in this PR. Four dated records capture official
sources, alternatives, consequences, compile evidence and later owners:

- [ADR-0004](../architecture/decisions/0004-platform-and-apple-apis.md): macOS 14 / Swift 6,
  pinned toolchain retained; independent full-access grants, application read/field
  limits, provider identity and incomplete-read semantics.
- [ADR-0005](../architecture/decisions/0005-google-desktop-boundary.md): desktop browser
  PKCE/loopback and app-created scope method audit. ACL and CalendarList operations
  are outside that scope; privacy and lost-destination recovery remain gated.
- [ADR-0006](../architecture/decisions/0006-local-mcp-and-processes.md): minimal stdio
  adapter and trusted app broker, current/legacy protocol boundary, signed-peer
  checks distinct from channel-bound pairing/revocation.
- [ADR-0007](../architecture/decisions/0007-lifecycle-identity-and-distribution.md):
  opt-in login, single local scheduler, separate development/production identity,
  broker Keychain and Developer ID/notarization strategy.

[PR-03's brief](prs/pr-03.md) is refined only; no models implemented. Source code,
permissions, entitlements, dependencies, CI/protections and canonical specification
are unchanged. No accounts, personal content or credentials accessed.

Remaining PR-02 work: staged/final-commit validation, diff/link review, push and PR
creation, then replace pending checkpoint/check fields here. Later feature blockers
are not unfinished PR-02 implementations: signed external-helper IPC and actual
client matrix (PR-17), trusted pairing (PR-19), private Google destination validation
(PR-09/16), scope classification/production consent and registered identity (PR-08),
recovery (PR-14), oldest-OS/runtime/Keychain/release proof (respective providers/PR-30).
Each ADR records the specific owner and closure trigger. Do not resolve these by
inventing evidence or expanding scope on the home Mac.

## Validation and limits

- Strict toolchain preflight passed; Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0.
- Disposable macOS 14 arm64/x86_64 API typechecks passed at the PR-01 base; negative
  Contacts `.limited` check failed as expected. No probe ran or was retained.
- Full staged/final local validation and history/index scanner: pending.
- Hosted Build and test / Secret scan: pending PR creation.
- No actual OS permission/API, signed sandbox/IPC, OAuth/account, MCP client,
  background, home-Mac, oldest-OS, signing or notarization behavior verified.

Exact tested commit and final local/hosted links must be recorded before handoff.
A later evidence-only commit cannot cite its own hash; compare the recorded tested
checkpoint to current PR head and read the final-head evidence in the PR description.

## Exact home-Mac checkout and validation

Use [setup](../development/setup.md) for prerequisites and local authentication.
Required baseline: Xcode **27.1 (27A9275)**, bundled Swift **6.4**, macOS SDK **27.0**;
Swift 6 mode. Host must support Xcode (Apple currently lists macOS 26.6+). Git 2.x,
Python 3.9+ and standard macOS utilities are required. The scanner is checksum-pinned
Gitleaks **8.30.1**, fetched temporarily by the script; no global install. No release
credentials needed. Choose `DEVELOPER_DIR` per process if discovery needs assistance;
never install/upgrade tools or change global selection automatically.

For a fresh clone, run from your chosen parent directory:

```sh
git clone --branch codex/pr-02-technical-feasibility --single-branch https://github.com/christianzbox/MacHandle.git
cd MacHandle
git fetch origin main
git status --short --branch
git rev-parse HEAD
```

For an existing clone, inspect and preserve local changes before switching:

```sh
git status --short --branch
git fetch origin --prune
# First checkout of this branch on this Mac:
git switch --track origin/codex/pr-02-technical-feasibility
# If it already exists, use this instead of the preceding switch:
# git switch codex/pr-02-technical-feasibility
git pull --ff-only
git rev-parse HEAD
```

If a single-branch clone does not fetch this branch, fetch it explicitly first:

```sh
git fetch origin refs/heads/codex/pr-02-technical-feasibility:refs/remotes/origin/codex/pr-02-technical-feasibility
```

After checking GitHub state/head/reviews and selecting the pinned Xcode:

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If the PR is already merged, do not keep writing to this branch or start PR-03
without direction. If fast-forward fails, follow setup's divergence procedure;
never discard changes or force-push. Chats, caches, stashes and local commits do
not transfer. Work-Mac editing must stop before the home Mac becomes the writer.

## Copyable next-session prompt

> Continue MacHandle PR-02 only on codex/pr-02-technical-feasibility. Read AGENTS.md,
> docs/implementation/pr-coordination.md, progress.md, the PR-02 roadmap row/brief,
> ADRs 0004–0007 and the relevant specification sections. Use the existing PR URL
> and checkpoint in coordination; fetch and fast-forward, preserve local changes,
> verify GitHub state/head/reviews and ensure no other Mac is writing. PR-01 is
> squash-merged at 4364fb79676de22d07cb6e5c01738481aad1f7d5; do not reuse its branch.
> If PR-02 is review-ready, address only requested review changes and verify the
> physical home-Mac setup with the pinned tools. If unfinished checks are listed,
> finish those first. Do not access personal data, add speculative permissions,
> install tools, change global Xcode settings or broaden into provider implementation.
> Stage intended files, run the three documented checks, record exact local/hosted
> evidence and limits, commit/push the existing PR and update this handoff. Leave
> PR-02 open for user review. Do not merge, enable auto-merge, publish or begin PR-03.

## Today's cutoff

User requested wrapping up by 17:10 and finishing by 17:20 on 2026-10-23
America/Detroit, ahead of a 17:30 departure. The session began before that cutoff.
If incomplete at cutoff, push a safe checkpoint and leave a draft PR with exact
remaining checks, then stop. If complete earlier, stop earlier for user review.
