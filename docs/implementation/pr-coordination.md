# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [setup](../development/setup.md), [progress](progress.md),
[slot 1](prs/private-reminders-slot-1.md) and [native acceptance](../development/private-native-bridge.md).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Finish private Reminders slot 1 — native app and MCP relay |
| Branch | codex/private-slot1-native-relay |
| GitHub PR | [GitHub PR #35](https://github.com/christianzbox/MacHandle/pull/35); exact final-head evidence in the PR |
| Implementation checkpoint | 50b5008b9a6f7303a1624f47368fcdb8ea3fe9a4; final handoff commit includes review links |
| Dependency | GitHub PR #34, verified merged; both hosted checks passed on 3043318987dd3e85005765b6fde96878db3f1de7 |
| Verified squash/base SHA | c63bee0419aea526761795fe93f02bf767b282cf |
| Merge time | 2026-10-30 10:46:31 America/Detroit (14:46:31 UTC) |
| Authorization | Finish the rest of slot 1 in one review PR; account-free, sample data, personal iCloud untouched |
| Product scope | Personal app first; no paid enrollment, employer signing, monetization or public release assumption |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | Review slot 1 completion; stop before merge or slot 2 |

## Scope, evidence and retained gates

[ADR-0038](../architecture/decisions/0038-private-native-mcp-relay.md) supplies the missing packaged
sandboxed native app, native per-launch consent and real stdio MCP relay. It derives mutual authority
from a disposable local certificate and exact sibling identifiers, verifies the bundle seal, preserves
the content-free XPC handshake, and reuses the existing broker/controller/adapter. The app's dependency
graph excludes live providers. The helper is hardened but unsandboxed and has no provider/policy/
approval implementation. Real native clicks are required; no approval endpoint or test bypass exists.

The normal three gates do not create identities or register services. Separate opt-in native
acceptance signs task-owned artifacts in a disposable keychain, temporarily registers a GUI-session
job, and exercises actual native Allow/Revoke clicks plus an external Python MCP client. Signed
resources, issuer/build isolation, initial denial, selected sample reads, hidden fields, write denial,
revocation, a sandbox-denied synthetic file and cleanup are checked. Exact local/native/hosted evidence
belongs in the review PR. No personal account, existing Keychain item, TCC/provider permission, personal
iCloud, client configuration, trust-store change, persistent install or release is involved.

The [finish line](../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line)
is one designated Mac. Slot 1 now has two authorized PRs; five planned slots remain. Minimum-OS runtime
is retained before expanding machines/claims; actual selected desktop-client acceptance is slot 5,
and stable private-build/upgrade handoff is slot 6. These explicitly clarify the earlier brief; do not
claim those checks ran. Real isolated Reminders reads are slot 2 and require new authorization.

## Resume on either Mac

Preserve changes, confirm one writer, fetch and inspect GitHub state, then fast-forward. Select pinned
Xcode/Swift/SDK per process via local DEVELOPER_DIR as needed:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/private-slot1-native-relay
# Other Mac first use: git switch --track origin/codex/private-slot1-native-relay
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Follow the [native runbook](../development/private-native-bridge.md) for the explicit process/UI
acceptance. A GUI session and local native actions are required. Do not substitute automatic approval,
real providers, an employer identity, broad entitlements or a permanent service to make tests pass.

## Copyable next-session prompt

> Resume slot 1 completion review on codex/private-slot1-native-relay. Read AGENTS, coordination,
> progress, the slot 1 brief, ADR-0038 and native acceptance runbook. Verify GitHub state and
> fast-forward with one writer. Address this PR only. Keep account-free local fixture signing,
> sandboxed sample app, real native approval, minimal MCP relay and no personal provider/iCloud.
> Do not touch employer certificates, existing Keychain items, OS permissions, client configuration,
> trust settings or persistent services. Run the three gates and explicit native/process acceptance
> on the final head; record local and hosted evidence separately. Push the same PR and stop before
> merge, auto-merge, release or slot 2. Minimum-OS/actual desktop client/stable upgrade gates remain
> where ADR-0038 assigns them; do not misrepresent current-host sample proof as full product readiness.
