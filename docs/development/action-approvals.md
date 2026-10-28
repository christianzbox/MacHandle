# Action approval development checks

Work package 20 uses only fixed in-memory Calendar writers. No Apple/Google developer account,
key, OS permission or installed MCP client is needed for these checks. Future personal setup
remains in the [account guide](google-auth-setup.md). This package adds no enrollment requirement.

## Automated checks

After selecting the pinned toolchain from [setup](setup.md):

```sh
swift test --filter 'ActionApprovalsTests|sampleAction'
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

The main suite includes exact writes to an isolated mock, preservation of unrelated fields/events,
concurrent confirmation/commit, bounded suspended preparations, revocation and expiry after awaits,
late accepted writes, changed state at the provider boundary, lost receipts and unknown-result
blocking. UI model tests reject stale IDs and clear dismissed reviews. Four new external compiler
probes reject access to the engine, confirmation, dispatch value and synthetic factory. The
existing MCP stdio/SDK matrix remains read-only and unchanged; it cannot approve an action.

## Native sample walkthrough

Open the unsigned Debug build and choose Connections → Sample action approval. Calendar discovery
and Google connection can remain off. Review Sample Update shows a title change and explicit
location clearing while retaining unrelated notes. Approve Sample Change reports that no real
calendar changed. Review Sample Delete keeps confirmation disabled until its separate checkbox
is selected. Cancel dismisses a review; a fresh sample resets its isolated fixture.

Scoped work-Mac inspection verified create/update/deletion completion, cancel, acknowledgement gating and literal
before/after layout. Accessibility-tree inspection found missing diff-row labels, corrected with
explicit field/before/after labels and rechecked. This is not full VoiceOver, minimum-OS, signed
runtime or real-provider acceptance. The preview app was quit afterward; no permission prompt,
real account, source content or installed client configuration was used. Screenshots remain outside Git.

## Before a live writer

Read [ADR-0025](../architecture/decisions/0025-action-proposal-approval.md) and the
[package 21 brief](../implementation/prs/pr-21.md). Trusted composition must supply the actual
verified connection/current OS gate and exact provider target evidence. Current MCP saved grants
remain read-only. Real write enablement also requires durable pre-dispatch records, unknown-result
recovery, supported provider version/occurrence checks and native live review. Confirmation is
local only; caller text, request IDs or protocol metadata cannot approve. Never retry an unknown
create. Do not promise rollback for a write already accepted by a provider.
