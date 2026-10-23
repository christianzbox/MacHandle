# PR coordination and home-Mac handoff

Updated: 2026-10-23, America/Detroit. Read [setup](../development/setup.md) for tool
installation, local authentication and divergence handling; [progress](progress.md)
for evidence. Git/GitHub hold the handoff, not chats, stashes or caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Work package / branch | PR-02 only / `codex/pr-02-technical-feasibility` |
| PR | [GitHub #3](https://github.com/christianzbox/MacHandle/pull/3), targeting `main`; leave open for user review |
| Pushed decision checkpoint | `fa4bfd399a95b54e5461b7e4cf3488ea3c29e104` |
| PR-01 dependency | [GitHub #1](https://github.com/christianzbox/MacHandle/pull/1), rechecked merged 2026-10-23 14:14:32 Detroit (18:14:32 UTC) |
| Actual squash merge / branch base | `4364fb79676de22d07cb6e5c01738481aad1f7d5`; fetched before creating PR-02 |
| Next action | User review; home Mac may verify setup or address requested PR-02 review changes only |
| Writer | Work-Mac session stops after final push/checks; only then may home Mac become the writer |

The checkpoint above contains the decisions; a subsequent documentation-only commit
adds this exact SHA and PR link. Its final tested head/CI results are recorded in the
PR description to avoid a self-referential Git hash. Read the PR's current head before
resuming. PR-02 is not merged; roadmap IDs are not GitHub PR numbers.

## Completed work and remaining gates

ADRs [0004](../architecture/decisions/0004-platform-and-apple-apis.md),
[0005](../architecture/decisions/0005-google-desktop-boundary.md),
[0006](../architecture/decisions/0006-local-mcp-and-processes.md) and
[0007](../architecture/decisions/0007-lifecycle-identity-and-distribution.md) record
dated sources, alternatives and tradeoffs: macOS 14/Swift 6; independent Apple
permissions and application policy; Google desktop PKCE/loopback and narrow scope;
stdio adapter/trusted broker; opt-in login, Keychain identity and Developer ID strategy.
PR-01 merge bookkeeping and [PR-03's brief](prs/pr-03.md) are updated. No PR-03 code.

No PR-02 implementation remains beyond review and final evidence publication on the
PR. Later blockers retain explicit owners: Google console classification/production
identity (PR-08), private-destination verification without ACL scope (PR-09/16),
lost-ID recovery (PR-14), signed external-helper IPC/client matrix (PR-17), trusted
pairing/revocation (PR-19), and runtime/Keychain/release gates in providers/PR-30.
Do not broaden scope to resolve those during this handoff.

## Validation and limitations

Decision checkpoint `fa4bfd399a95b54e5461b7e4cf3488ea3c29e104`:

- Strict `check_environment.sh`: passed (0.2s). `validate.sh`: passed (5.4s),
  formatting, package build, 1 Swift + 13 Python tests, zero failures/skips,
  unsigned Debug/Release builds, analysis and indexed privacy/whitespace checks.
- `scan_secrets.sh`: passed (1.2s), checksum-pinned scanner, history/index, no detected leaks.
- 420 local links/anchors/exact-case paths passed at that checkpoint; specification
  and LICENSE unchanged, all 31 roadmap entries retained. 421 links/anchors/case checks passed after the handoff update.
- [Hosted checkpoint CI](https://github.com/christianzbox/MacHandle/actions/runs/40007318162): both Build and test (1m59s) and Secret scan (6s) passed on that exact head.
- Disposable macOS 14 arm64/x86_64 API typechecks passed; Contacts `.limited` rejected
  as expected. No prototype ran or was retained. See [experiment details](prs/pr-02.md#evidence-and-experiments).

No actual TCC/provider, signed sandbox/IPC, Google/MCP client, background, oldest-OS,
home-Mac, signing or notarization proof. No personal accounts/data/credentials,
permissions, entitlements or global settings changed. Research and compile evidence
are distinct from future live acceptance. Local logs are supplemental temporary
files; necessary results are preserved here and on the PR.

## Home-Mac commands

Required pins: **Xcode 27.1 (27A9275), Swift 6.4, macOS SDK 27.0**, host compatible
with Xcode (currently macOS 26.6+). Git 2.x, Python 3.9+ and macOS utilities per
[setup](../development/setup.md); Gitleaks **8.30.1** is fetched temporarily with hash
verification by the scanner. No paid signing credentials needed. Use local
`DEVELOPER_DIR` if necessary; no automatic installs or global Xcode selection changes.

Fresh clone from your chosen parent directory:

```sh
git clone --branch codex/pr-02-technical-feasibility https://github.com/christianzbox/MacHandle.git
cd MacHandle
```

Existing clone: inspect/preserve changes first, then fetch and fast-forward:

```sh
git status --short --branch
git fetch origin --prune
# First checkout here; if already present, use the commented switch instead:
git switch --track origin/codex/pr-02-technical-feasibility
# git switch codex/pr-02-technical-feasibility
git pull --ff-only
```

For a clone restricted to another branch, first add/fetch this branch with
`git remote set-branches --add origin codex/pr-02-technical-feasibility` and
`git fetch origin`. Follow setup for any divergence; never discard or force-push.
Then inspect PR/head/reviews and validate (GitHub CLI is optional; browser also works):

```sh
git rev-parse HEAD
gh pr view 3 --json state,isDraft,headRefName,headRefOid,url
gh pr checks 3
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

If already merged, stop for direction. Do not reuse PR-01's deleted remote branch,
push bookkeeping to main, merge, enable auto-merge, publish or begin PR-03.

## Copyable next-session prompt

> Continue MacHandle PR-02 only, GitHub https://github.com/christianzbox/MacHandle/pull/3,
> branch codex/pr-02-technical-feasibility. Read AGENTS.md, coordination, progress,
> the PR-02 roadmap row/brief and ADRs 0004–0007; use the canonical master plan and
> relevant spec sections. Fetch/fast-forward, preserve changes, compare the pushed
> checkpoint and current PR head, and ensure the work Mac has stopped writing.
> PR-01 is merged at 4364fb79676de22d07cb6e5c01738481aad1f7d5. PR-02 decisions are
> complete for review; verify physical home-Mac setup with pinned tools and address
> only requested review feedback. Recheck final-head CI in the PR. Do not access
> personal data, add speculative permissions, install tools or change global Xcode
> settings automatically. Stage intended changes, run all three documented checks,
> record exact local/hosted evidence and limitations, commit/push the same PR and
> refresh this handoff. Do not merge, auto-merge, publish or implement PR-03.

Today's stop rule: wrap by 17:10 and finish by 17:20 on October 23, 2026 Detroit
(before the user's 17:30 departure). This session began earlier and completes early;
no background work is scheduled. Stop after final verification and user-review handoff.
