# Contributing

Start with [AGENTS.md](AGENTS.md), [current state](Docs/CURRENT_STATE.md), and the
active PR brief from current state. Resume an existing open PR before starting
the next eligible roadmap item. Keep changes focused and target `main` through
a feature-branch pull request. The maintainer reviews and merges; agents stop
with the PR open. Preserve the existing Apache-2.0 license.

Follow [setup and cross-Mac handoff](Docs/DEVELOPMENT.md) for the exact shared
toolchain, clean-clone commands, Git checkpoint/push workflow, and Codex setup.
Use Xcode and SwiftPM; see [testing](Docs/TESTING.md). Stage intended files, inspect
the complete diff, run both validation scripts, and include actual test results
and limitations in the PR. Use only synthetic data. Never commit credentials,
calendar/contact exports, databases, personal configurations, logs, or screenshots
containing private data. `.gitignore` does not protect already tracked files.

Do not bundle future roadmap work into a foundation PR. Update architecture,
current state, roadmap, affected ADRs, and the next focused brief with each change.
Report security issues according to [SECURITY.md](SECURITY.md).
