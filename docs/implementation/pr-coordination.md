# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [slot 1 acceptance](prs/private-reminders-slot-1.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Private Reminders slot 1 — external helper and identity |
| Branch | codex/external-helper-identity |
| GitHub PR | Being prepared; review link and exact head will be recorded before handoff |
| Dependency | Native sample bridge, merged in GitHub PR #33 |
| Verified squash/base SHA | 94df5e5b1654268d711f4cd2bf498163e73e028d |
| Merge time | 2026-10-30 10:10:42 America/Detroit (14:10:42 UTC) |
| Authorization | One slot 1 review PR; sample data only; personal iCloud untouched; paid enrollment postponed and employer signing resources excluded |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Next action | Review this PR's account-free portion; full slot 1 acceptance stays open; resolve/re-scope remaining gates before another implementation PR |

The original 31 work packages and the native sample bridge are merged. The
[six-slot private Reminders finish line](../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line)
is the bounded follow-up plan. Slots 2–6 are not authorized. Do not silently increase the PR count,
weaken the finish line or advance to native providers on fixture evidence.

## Scope, evidence and limits

[ADR-0037](../architecture/decisions/0037-external-helper-identity.md) adds mutual actual-channel XPC
requirements, a content-free verified handshake before forwarding each read, separate sample broker/
probe executables, and an explicit temporary GUI-session launchd harness. Fixture copies are ad-hoc
signed with exact code hash + identifier; no developer certificate, employer account or Keychain is
used. Reuse NativeReadBroker, connection/controller and field projection. The probe has no provider,
policy, approval, persistence or credential dependency. No wire approval or writes.

Normal three gates compile/unit-test without service registration. The additional opt-in process
check verifies independent processes, wrong peers in both directions before broker dispatch, selected
sample reads, unapproved denial, per-launch separation, absence/termination and checked cleanup.
Exact final evidence belongs in the PR. Hosted CI does not run temporary launchd registration.

The fixture is unsandboxed and uses a native read-envelope probe, not a working desktop MCP relay.
Sample approval is a harness-local decision, not user consent. Packaged sandbox discovery, native
approval handoff, real MCP relay, suitable personal signing setup, minimum/current OS and actual
client acceptance remain open slot 1 gates. No app entitlement change, persistent service install,
client configuration, permission prompt, account creation, live provider, release or personal iCloud.

## Resume on either Mac

Preserve user changes, confirm one writer, fetch and inspect GitHub state before edits. Select pinned
Xcode/Swift/SDK per process via local DEVELOPER_DIR as needed:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/external-helper-identity
# Other Mac first use: git switch --track origin/codex/external-helper-identity
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

For this PR's explicit temporary process checks, follow the [runbook](../development/external-helper.md).
No permanent registration or real accounts are needed. Stop if the GUI-session prerequisite is absent;
do not substitute a global service or weaken sandbox entitlements.

## Copyable next-session prompt

> Resume slot 1 review on codex/external-helper-identity. Read AGENTS, coordination/progress,
> slot 1 brief, ADR-0037 and the six-slot finish line. Verify GitHub merge/PR state and fast-forward
> with one writer. Address this PR only. Keep task-owned synthetic fixtures and account-free ad-hoc
> copies; no employer certificates, personal iCloud, live provider/TCC, permanent services, client
> install, entitlement changes or publication. Run normal gates and the documented explicit process
> harness; record exact local/hosted evidence. Push the same PR and stop before merge or another slot.
> Do not call slot 1 complete until its packaged sandbox/native app/MCP acceptance is resolved.
