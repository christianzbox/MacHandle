# Full local validation and ready-PR CI

Status: implemented for review. Branch: `codex/local-validation-ready-pr-ci`.
One authorized maintenance PR: [GitHub PR #41](https://github.com/christianzbox/MacHandle/pull/41). Exact-head
evidence belongs in the PR; [coordination](../pr-coordination.md) owns the handoff.

Dependency: GitHub PR #40 verified merged at
`513b8b5aa2ff437ab9f0f6c8cb5dd04c222ad7dc` on 2026-10-30 18:46:16 UTC.
Read [ADR-0044](../../architecture/decisions/0044-local-validation-ready-pr-ci.md),
[testing](../../development/testing.md#local-development-and-final-hosted-verification)
and [specification §21](../../product/master-spec.md#21-cicd-and-release-safety).

| Outcome | Acceptance |
| --- | --- |
| Local coverage | All existing validation and secret-scanning scripts retained; full gates before the final review push; exact toolchain limits reported |
| Draft checkpoints | No runner allocation; distinct skipped names do not satisfy required check names |
| Ready gate | Full existing build/test and secret-scan jobs on ready creation/transition, ready updates and reopening |
| Return to draft | Cancel superseded work through the existing concurrency group |
| Merge | No duplicate main-push job; existing strict up-to-date required checks preserved |
| Handoff | AGENTS, template, setup/testing, roadmap, progress and coordination describe the same workflow |

The maintainer selected the preinstalled hosted Xcode 27.1 (27A9275), Swift 6.4
and SDK 27.0 baseline, with local 27.2 retained alongside it. This supersedes the
proposed 27.2 upgrade; [ADR-0045](../../architecture/decisions/0045-xcode-27-2-baseline.md)
records the tradeoffs and future upgrade procedure. Engineering verifies exact
hosted availability before changing the shared pin. CI does not download Xcode.
Local 27.1 installation and exact preflight are verified. All three strict local
gates must pass before the final push and ready transition; both hosted checks
must pass on the current revision. Exact final results belong in PR #41.

No app/test removal, permission activation, billing-setting change, self-hosted
runner installation or repository-protection change. Stop with this PR open;
no merge, auto-merge or next feature.
