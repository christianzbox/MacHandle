# PR coordination and home-Mac handoff

Updated: 2026-10-26, America/Detroit. Git/GitHub carry the handoff; see
[setup](../development/setup.md) and [progress](progress.md).

## Active work and next action

| Field | Value |
| --- | --- |
| Work package / branch | PR-03 only / `codex/pr-03-core-domain-models` |
| PR | To be opened after staged validation; exact URL/head will be recorded before final handoff |
| Dependency | PR-02 merged in [GitHub #3](https://github.com/christianzbox/MacHandle/pull/3) |
| Verified squash/base SHA | `c96f4f0cbb54e2397d5c987a80cc2c0cd9ab0630` |
| Merge time | 2026-10-23 15:24:58 America/Detroit (19:24:58 UTC); rechecked on GitHub 2026-10-26 |
| Authorization | User authorized PR-03 on 2026-10-26; no home-Mac work had begun |
| Writer | Work Mac only until final pushed handoff; home Mac remains unverified |
| Next action | Finish standard checks, push/open PR-03, then stop for user review |

## Delivered scope and evidence

One independent CoreDomain target: namespaced typed identities, immutable Sendable
calendar/occurrence/availability, Reminder/Contact values, explicit field/read/error
states, resource-specific operations and exact proposals with mutation preconditions.
Separate async CalendarReading/CalendarWriting protocols have no provider implementation.
[ADR-0008](../architecture/decisions/0008-core-domain-contracts.md) explains choices,
alternatives, limits and future gates. [PR-03](prs/pr-03.md#implementation-and-acceptance-map)
maps acceptance to tests; [PR-04](prs/pr-04.md) is a planned brief only.

Focused checks passed: 18 domain tests plus 1 foundation test, zero failures/skips;
dependency/import guard, positive compiler control and three expected type rejections.
Standard staged/final-commit evidence and hosted results will be recorded on the PR
before final handoff. Earlier PR-02 head/results remain historical in progress/PR #3.

No real provider, TCC, policy engine, trusted approval, storage, network, Google/MCP,
UI feature, signed sandbox, oldest-OS or home-Mac behavior is verified. The app window
and runtime permissions are unchanged. No personal data, secrets, signing identity,
installation or global tool selection changes. Models do not prove authorization,
upstream freshness, cross-resync identity, atomic writes or safe deletion.

## Resume on either Mac

Use the pinned Xcode 27.1 (27A9275), Swift 6.4 and SDK 27.0 per [setup](../development/setup.md).
Inspect/preserve local changes before switching; one active writer per branch.

```sh
git status --short --branch
git fetch origin --prune
# First checkout of this feature branch:
git switch --track origin/codex/pr-03-core-domain-models
# If it already exists locally, use: git switch codex/pr-03-core-domain-models
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Fresh clone: clone the repository's `codex/pr-03-core-domain-models` branch using
the normal GitHub URL in setup. Read the PR's current state/head/reviews before edits.
Do not resume the deleted PR-02 remote branch. If PR-03 has merged, verify its actual
merge SHA and stop for direction; do not push bookkeeping to main or begin PR-04.
Home-Mac setup is an outstanding device check, not a prerequisite for this package.

## Copyable next-session prompt

> Continue MacHandle PR-03 only on codex/pr-03-core-domain-models. Read AGENTS,
> coordination/progress, PR-03's acceptance map and ADR-0008; inspect the current
> GitHub PR/head/checks. PR-02 merged at c96f4f0cbb54e2397d5c987a80cc2c0cd9ab0630.
> Fetch/fast-forward after preserving changes and confirming the other Mac stopped
> writing. Address requested PR-03 review feedback or verify home setup only; no
> providers, policy engine, accounts or permissions. Stage/review intended files,
> run all three standard commands, commit/push the same PR and record exact evidence.
> Stop for user review. Do not merge, auto-merge, publish or implement PR-04.
