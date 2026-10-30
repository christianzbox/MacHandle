# PR coordination and home-Mac handoff

Updated: 2026-10-30, America/Detroit. Read [setup](../development/setup.md),
[progress](progress.md) and [native bridge acceptance](prs/native-bridge.md#implementation-and-acceptance).
Git/GitHub carry the handoff, not chats or local caches.

## Active work and next action

| Field | Value |
| --- | --- |
| Follow-up | Native bridge — sample pairing and reads |
| Branch | codex/native-bridge-sample-pairing |
| GitHub PR | Pending creation |
| Dependency | Work package 31, merged in GitHub PR #32 |
| Verified squash/base SHA | 34ad4c3e4e0165123cda48b9b3808adab8e7fd36 |
| Merge time | 2026-10-29 12:52:36 America/Detroit (16:52:36 UTC) |
| Authorization | User requested native bridge PR with sample data only and personal iCloud untouched; resumed after merge verification |
| Writer | Work Mac only; home-Mac setup remains unverified |
| Implementation checkpoint | Pending commit; exact final evidence belongs in the PR |
| Next action | Finish validation and open one review PR; stop before merge or another activation slice |

The original 31 work packages are merged. This is a separately authorized follow-up, not GitHub/work
package renumbering. [Activation index](activation-backlog.md) retains the remaining requirements.

## Scope, evidence and limits

[ADR-0036](../architecture/decisions/0036-native-bridge-sample-pairing.md) adds native local review,
a read-only app-side broker and a sample anonymous XPC transport. Connections offers an explicit
sample launch, expiring review, selected fixture Reminders reads, disconnect and revoke. The wire
cannot select identity, approve itself, configure grants or mutate. Existing controller/adapter/parser
checks are reused; broker and fixture factory remain package internal. All state is memory-only.

Both XPC endpoints run inside the app/test process. No separately launched helper, signed peer,
service discovery, real OS authorization/provider or actual ChatGPT acceptance is claimed. No account,
credential, signing, permission prompt, named/remote listener, durable store, release or personal iCloud
access. No entitlement changes. The standalone synthetic stdio helper is unchanged.

Staged gates passed before final documentation polish: environment 0.23 s, validate 59.78 s,
secret scan 1.65 s. 454 Swift tests (nine new), 32 Python checks, 53 expected compiler rejections,
SwiftPM/native builds/analyzer and privacy checks passed. The new tests cover actual XPC within one
process, native model cleanup, hidden data, bounded concurrency, cancellation/revocation and timeout.
Documentation check: 1,399 links/anchors and all 31 roadmap anchors; protected files/entitlements
unchanged. Exact final-head repeats and hosted results belong in the linked PR. No interactive app
or signed sandbox/provider acceptance was performed.

## Resume on either Mac

Use pinned Xcode 27.1 (27A9275), Swift 6.4, SDK 27.0, selected per process. Preserve changes and
confirm one writer. Fetch, inspect the PR and fast-forward before edits:

```sh
git status --short --branch
git fetch origin --prune
git switch codex/native-bridge-sample-pairing
# Other Mac first use: git switch --track origin/codex/native-bridge-sample-pairing
git pull --ff-only
git rev-parse HEAD
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Do not enable a provider, configure accounts or register a service to run the fixture checks.
Signed external-helper discovery/mutual peer rejection remains the next separately scoped gate.

## Copyable next-session prompt

> Continue the native bridge sample pairing PR on codex/native-bridge-sample-pairing. Read AGENTS,
> coordination/progress, ADR-0036 and the focused native-bridge brief. Verify GitHub PR #32 merged
> at 34ad4c3e4e0165123cda48b9b3808adab8e7fd36; preserve changes and fetch/fast-forward with one writer.
> Address this PR's review only. Keep fixed fixtures, anonymous in-process XPC, memory state and
> native-only approval. No personal iCloud, live provider/permission, credential/signing, external
> helper activation, registered service, remote listener, client install or publication. Stage/review,
> run all three gates, commit/push the same PR and record exact local/hosted evidence. Stop before
> merge/auto-merge or another activation slice; retain signed/provider and all existing release gates.
