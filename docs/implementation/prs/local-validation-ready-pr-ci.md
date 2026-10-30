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

The maintainer additionally authorized upgrading the exact shared baseline to
Xcode 27.2 (27B52), Swift 6.4.2 and SDK 27.2 in
[ADR-0045](../../architecture/decisions/0045-xcode-27-2-baseline.md). Run the full
strict local gates without the override. The hosted image currently offers only
27.2 RC 27B48; engineering owns rechecking when the image updates and running
both full checks. Keep this PR draft until that prerequisite is available.

No app/test removal, permission activation, billing-setting change, runner
installation or repository-protection change. Stop with this PR open; no merge,
auto-merge or next feature.
