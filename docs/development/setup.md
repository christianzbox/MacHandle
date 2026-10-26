# Development on work and home Macs

Both Macs use the same Git repository, feature branches, checked-in Xcode project,
Swift package, shared scheme, formatting rules, toolchain baseline, and validation
commands. Neither Mac is the authoritative working copy: pushed Git commits and
GitHub PRs are the handoff. Choose any clone location; do not copy build caches,
local credentials, or a Codex conversation to make another checkout work.

## Required tools

| Tool | Requirement | Installation / purpose |
| --- | --- | --- |
| Development macOS | A host supported by Xcode 27.1: Tahoe 26.6 or later | Check Apple's requirements before installing; this differs from the app's macOS 14 implementation target (runtime acceptance remains open). |
| Full Xcode | **27.1, build 27A9275** | Download this version from Apple; Command Line Tools alone are insufficient. |
| Swift, SwiftPM, swift-format | **Apple Swift 6.4**, bundled with that Xcode | No separate Swift or formatter installation. Swift language mode is 6; the package manifest's tools-version 6.2 is a minimum manifest format, not the selected compiler. |
| macOS SDK | **27.0**, bundled with that Xcode | Do not download or select an unrelated SDK. |
| Git | 2.23+ (`git switch` support) | Apple's developer tools supply Git; newer compatible versions are fine. |
| Bash | 3.2+ | macOS `/bin/bash`; scripts work even when your interactive shell is zsh. |
| Python | 3.9+ | Repository checks use only the standard library, no pip packages. Xcode supplies Python; check `python3 --version`, or install Python 3 from python.org if absent. |
| curl, shasum, tar | macOS system utilities | Download/checksum verification of the security scanner. Internet access to GitHub is required for cloning, fetching, and scanner downloads. |
| Gitleaks | 8.30.1 | `scan_secrets.sh` downloads a hash-verified binary to a temporary directory and removes it; no global install. |
| GitHub CLI | Optional, current 2.x | Install from cli.github.com for PR checkout/status; browser + Git also work. Authenticate separately on each Mac. |
| Codex | Optional, current supported app or CLI | Not a build dependency. Sign in separately and add/trust the local clone after inspecting its configuration. |

`Config/Toolchain.env` is the executable source of truth for exact build versions.
The tuple was observed in a successful CI run, including the Swift patch and SDK.
Utility minimum versions above are compatibility requirements, not artifact pins.
There are no third-party Swift packages, package generators, Homebrew requirements,
Node/Python daemons, Docker services, OAuth credentials, or paid signing identities
needed to build and test PR-01. There is no Package.resolved while there are no
external dependencies. When one is added, commit the applicable lockfile and
review its version, license, security, and both-machine setup.

References: [Apple Xcode host requirements](https://developer.apple.com/xcode/system-requirements),
[Apple downloads](https://developer.apple.com/download/all/),
[GitHub runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).
Host compatibility is separate from compiler checks; neither a build nor CI proves
that an untested Mac model/OS supports Xcode. The home Mac has not been tested yet.

## Set up either Mac

1. Install the exact Xcode baseline and launch it once to accept Apple's license
   and finish first-launch components. It can coexist with another Xcode version.
   Do not replace another project's Xcode installation. If the host cannot run
   this Xcode, resolve that prerequisite or propose a reviewed baseline change.
2. Check Git/Python availability. For pushing, configure your Git name/email
   (a GitHub noreply address is suitable for a public repo) and GitHub authentication
   on this Mac. Use a credential manager or per-device SSH key; never put a token
   in a clone URL, tracked file, or shell command. `gh auth login` is optional.
3. In your chosen parent directory, clone and enter the repository:

   ```sh
   git clone https://github.com/christianzbox/MacHandle.git
   cd MacHandle
   ```

   PR-01 is merged and main contains the foundation. For active work, follow the
   exact branch and PR commands in [coordination](../implementation/pr-coordination.md).
   If that branch already exists locally, use the resume procedure below instead.
4. Verify and validate from the clone root:

   ```sh
   bash Scripts/check_environment.sh
   bash Scripts/validate.sh
   bash Scripts/scan_secrets.sh
   ```

   On a clean clone all source files are already indexed, so no staging is needed.
   During development, stage intended new/changed files before the privacy/secret
   checks, review the staged diff, and avoid blanket staging of unknown files.
5. Open the checked-in `MacHandle.xcodeproj` with the **baseline Xcode application**,
   select the shared `MacHandle` scheme, and edit/build normally. Merely double-clicking
   a project can open another installed Xcode; verify Xcode > About Xcode. The scripts
   build Debug and Release with signing disabled so neither Mac needs a developer
   team. The default development build also uses local ad-hoc signing ("Sign to Run
   Locally"), verified without a team or signing override. Developer ID signing,
   runtime sandbox verification and distribution remain later work. Run the scripts
   for tests: the app scheme's Test action currently has no test targets; the synthetic
   Swift test is in the local package and is exercised by `validate.sh`.

The preflight honors `DEVELOPER_DIR` if explicitly set. Otherwise it checks the
system-selected full Xcode and standard `/Applications/Xcode*.app` installations
for the exact baseline. A renamed app or installation elsewhere is supported by
setting `DEVELOPER_DIR` to that app or its `Contents/Developer` directory in the
current terminal. Paths containing spaces are supported. Do not commit that local
path. The scripts never run `sudo xcode-select` or alter global developer selection.
Selection happens before the Python version probe, since Apple's Python launcher
also depends on the developer directory. A separate Python installation is optional.

For example, if you chose this conventional installation name:

```sh
DEVELOPER_DIR="/Applications/Xcode_27.1.app/Contents/Developer" bash Scripts/validate.sh
```

The standard command fails clearly on mismatched Xcode build, Swift, or SDK. A
newer local toolchain can run supplemental checks explicitly:

```sh
bash Scripts/validate.sh --allow-toolchain-mismatch
```

This prints a compatibility-only warning and does **not** prove the baseline works.
CI rejects that override. The work Mac already has this exact baseline; the
home Mac must install/select it too. CI supplies independent baseline validation.
GitHub currently labels the `xcode-27` runner preview, so its availability remains
a CI dependency to monitor. The script selects only the exact pinned Xcode build,
not the runner default or an installed newer beta. Updating Xcode is a deliberate change to
`Config/Toolchain.env`, this guide, the ADR/evidence, and both Macs; do not silently
adopt an App Store update. Reproducible configuration does not imply byte-identical
unsigned binaries across architectures or OS patches.

## Continue an unfinished branch or PR on the other Mac

Use one active writer per feature branch. Before switching machines:

1. Stop editing on the first Mac. Review `git status` and the diff.
2. Update `docs/implementation/progress.md` with completed work and test evidence;
   update `docs/implementation/pr-coordination.md` with the active branch/PR,
   remaining steps, blockers and next action.
   Put architecture decisions in ADRs, scope in the PR brief, and review discussion
   in the existing GitHub PR. Clearly label failing/incomplete work.
3. Stage only intended source/docs, review `git diff --cached`, run privacy and
   secret checks, and commit a coherent checkpoint (even if the feature is unfinished).
   Never use GitHub as storage for private state or credentials. A stash, untracked
   files, or an unpushed local commit will not appear on the other Mac.
4. Push the existing feature branch and confirm GitHub has the commit:

   ```sh
   git push -u origin HEAD
   git rev-parse HEAD
   git status --short --branch
   ```

   Confirm the PR head SHA matches. Use the existing PR; mark it draft if it is no
   longer review-ready. If there is no PR yet, open one draft PR for the checkpoint.
   Update its description with actual validation and outstanding work. Do not merge.

On the other Mac, start with a clean worktree (inspect local changes before switching):

```sh
git status --short --branch
git fetch origin --prune
# First checkout of this feature branch on this Mac:
git switch --track origin/codex/native-application-foundation
# If it already exists locally, use this instead of the previous command:
# git switch codex/native-application-foundation
git pull --ff-only
git rev-parse HEAD
```

These commands use the native-application branch (work package 05) as a concrete example. For later work,
substitute the exact branch shown in the PR/coordination register. Inspect that
PR's state, comments and checks on GitHub. Roadmap IDs are not GitHub PR numbers.
Verify that it is still open and the SHA matches the checkpoint before resuming.

If fast-forward fails, both machines may have commits. Inspect
`git log --left-right --oneline 'HEAD...@{upstream}'`; preserve both sides and resolve
the divergence deliberately. Do not reset, discard, or force-push the other Mac's
work. Do not rebase an already shared branch merely to switch machines. Main's
linear-history requirement applies to the eventual squash merge, not to discarding
feature-branch history. Switching machines does not require merging main or
opening another PR. Repeat this procedure when returning to the first Mac.

## Codex context travels through GitHub

Open the new clone as a local Codex project. Root `AGENTS.md` defines the same
scope, validation commands, security invariants, and stop-for-review workflow on
both Macs. `.codex/config.toml` shares instruction discovery settings only: a
32 KiB instruction budget and CONTRIBUTING fallback if AGENTS is absent. It does
not set a model, credentials, local paths, permissions, or approval overrides.
Project trust and account authentication are local choices on each Mac. Optional
Codex app actions can call the same three setup/validation commands above; no
app-specific action or local session state is required to build or resume.

Official references: [project configuration and trust](https://developers.openai.com/codex/config-basic),
[instruction settings](https://developers.openai.com/codex/config-reference), and
[optional local environment actions](https://developers.openai.com/codex/app/local-environments).
Review configuration before trusting a clone. Shared settings do not synchronize
chats, local stashes, permissions, shell profiles, or credentials.

A fresh session can start with:

> Resume the existing MacHandle PR shown in docs/implementation/pr-coordination.md.
> Read AGENTS.md, progress, the active roadmap row/brief and relevant ADRs. Fetch
> the branch and inspect the GitHub PR, comments, and checks. Preserve unfinished
> work and continue only this PR; do not create a replacement branch/PR. Run the
> documented checks, update the handoff in Git, commit and push, then leave the PR
> open for review. Do not merge or begin the next roadmap item.

GitHub holds the canonical specification, decisions, progress, tests, PR description,
review discussion, and CI evidence. Avoid referring to an earlier private chat as
necessary context. Do not commit `~/.codex`, auth files, private skills, caches,
absolute checkout paths, or machine-specific signing settings. `.codex` is ignored
except for its intentionally shared config; adding future shared files requires
an explicit reviewed ignore-rule change.
