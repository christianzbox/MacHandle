# Contributing

Start with [AGENTS.md](AGENTS.md), [coordination](docs/implementation/pr-coordination.md),
[progress](docs/implementation/progress.md), and the active roadmap row/PR brief. Resume an existing open PR before starting
the next eligible roadmap item. Keep changes focused and target `main` through
a feature-branch pull request. The maintainer reviews and merges; agents stop
with the PR open. Preserve the existing Apache-2.0 license.

Follow [setup and cross-Mac handoff](docs/development/setup.md) for the exact shared
toolchain, clean-clone commands, Git checkpoint/push workflow, and Codex setup.
Use Xcode and SwiftPM; see [testing](docs/development/testing.md). Stage intended files, inspect
the complete diff, run both validation scripts, and include actual test results
and limitations in the PR. Use only synthetic data. Never commit credentials,
calendar/contact exports, databases, personal configurations, logs, or screenshots
containing private data. `.gitignore` does not protect already tracked files.

Do not bundle future roadmap work into a foundation PR. Update architecture,
progress, coordination, roadmap, affected ADRs, and the next focused brief when
prerequisite decisions change. Follow the [master plan](plans/MacHandleMasterImplementationPlan.md)
and keep the [complete specification](docs/product/master-spec.md) canonical.
Report security issues according to [SECURITY.md](SECURITY.md).
