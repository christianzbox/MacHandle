# PR coordination and home-Mac handoff

Updated: 2026-11-10, America/Detroit. Read [progress](progress.md),
[active brief](prs/sample-pairing-on-first-call.md), and [testing](../development/testing.md).

| Field | Value |
| --- | --- |
| Follow-up | Pair sample sessions on the first tool call |
| Branch | `codex/sample-pair-on-first-call` |
| Dependency | GitHub PR #43 verified merged at `f102ae29c6d1ae9bce64812e6089e3758c3b513c` |
| Scope | Sample-only startup race and signed harness coverage. Preserve all required local and hosted checks. |
| Writer | Current Mac only, in an isolated checkout |
| Next action | Validate locally, open for review, and retest the actual Codex sample read using a separately built installation. |

Use the [sample handoff](../development/private-testing-handoff.md) for installation and cleanup.
Keep the previous path-bound installation and journal intact. Native approval remains explicit.
Record local, hosted, and actual desktop evidence separately. Follow [setup and Git handoff](../development/setup.md)
before changing Macs. Stop with the PR open for maintainer review.
